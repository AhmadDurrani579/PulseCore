//
//  PulseCoreProcessor.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#import "PulseCoreProcessor.h"
#ifdef __OBJC__
#undef NO
#undef YES
#endif

#import <opencv2/opencv.hpp>

// Restore ObjC macros after OpenCV
#ifdef __OBJC__
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
#endif

// C++ headers
#include "../Core/Signal/PPGProcessor.hpp"
#include "../Core/Signal/SignalProcessor.hpp"
#include "../Core/Quality/QualityFilter.hpp"
#include "../Core/Inference/AFibDetector.hpp"
#include "../Core/Inference/GlucoseEstimator.hpp"
#include "../Core/Inference/StressRecoveryScore.hpp"
#include "../Core/Inference/WellnessScorer.hpp"
#include "../Core/Inference/CalibrationEngine.hpp"
#include "../Core/Warning/EarlyWarningEngine.hpp"
#include "../Core/Signal/rPPGProcessor.hpp"

#import <CoreVideo/CoreVideo.h>

// ── ObjC result classes ───────────────────────────────────────────────────

@implementation PulseCoreQualityResult
@end

@implementation PulseCoreResult
@end

// ── Main processor ────────────────────────────────────────────────────────

@interface PulseCoreProcessor() {
    PulseCore::PPGProcessor         _ppgProcessor;
    PulseCore::rPPGProcessor        _rPPGProcessor;
    PulseCore::SignalProcessor      _signalProcessor;
    PulseCore::QualityFilter        _qualityFilter;
    PulseCore::AFibDetector         _afibDetector;
    PulseCore::GlucoseEstimator     _glucoseEstimator;
    PulseCore::StressRecoveryScore  _stressScorer;
    PulseCore::WellnessScorer       _wellnessScorer;
    PulseCore::CalibrationEngine    _calibrationEngine;
    PulseCore::EarlyWarningEngine   _warningEngine;

    PulseCore::PPGFrame             _lastFrame;
    BOOL                            _hasLastFrame;
    float                           _sampleRate;
    int                             _frameCount;
    double                          _firstTimestamp;
}
@end

@implementation PulseCoreProcessor

- (instancetype)init {
    self = [super init];
    if (self) {
        _hasLastFrame = NO;
        _sampleRate   = 30.0f;
        _frameCount   = 0;
    }
    return self;
}

// ── Process camera frame ──────────────────────────────────────────────────
- (PulseCoreQualityResult*)processSampleBuffer:(CMSampleBufferRef)buffer
                                          mode:(PulseCoreScanMode)mode {

    PulseCoreQualityResult* qualityResult = [[PulseCoreQualityResult alloc] init];
    qualityResult.passed  = NO;
    qualityResult.score   = 0.0f;
    qualityResult.issue   = PulseCoreQualityIssueNotEnoughData;
    qualityResult.message = @"Hold still...";

    // Get real timestamp from CMSampleBuffer
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
    double timestamp = CMTimeGetSeconds(pts);

    // Measure real FPS
    _frameCount++;
    if (_frameCount == 1) {
        _firstTimestamp = timestamp;
        _ppgProcessor.setScanStartTime(timestamp);
    }
    
    double elapsed = timestamp - _firstTimestamp;
    if (elapsed > 1.0 && _frameCount > 10) {
        _sampleRate = static_cast<float>(_frameCount / elapsed);
    }

    // Convert CMSampleBuffer to cv::Mat
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    if (!imageBuffer) return qualityResult;

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    int width  = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    void* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);

    cv::Mat bgraFrame(height, width, CV_8UC4, baseAddress);
    cv::Mat bgrFrame;
    cv::cvtColor(bgraFrame, bgrFrame, cv::COLOR_BGRA2BGR);

    CVPixelBufferUnlockBaseAddress(imageBuffer,
                                   kCVPixelBufferLock_ReadOnly);

    // Process finger scan
    if (mode == PulseCoreScanModeFinger) {
        PulseCore::PPGFrame frame = _ppgProcessor.processFrame(bgrFrame, timestamp);

        // Store real timestamp in frame
        frame.timestamp = timestamp;

        // Check motion against last frame
        if (_hasLastFrame) {
            if (_qualityFilter.hasMotion(frame, _lastFrame)) {
                qualityResult.issue   = PulseCoreQualityIssueMotionDetected;
                qualityResult.message = @"Keep your finger still";
                _lastFrame    = frame;
                _hasLastFrame = YES;
                return qualityResult;
            }
        }

        _lastFrame    = frame;
        _hasLastFrame = YES;

        // Check signal quality
        PulseCore::PPGSignal signal = _ppgProcessor.getSignal();
        PulseCore::QualityResult quality =
            _qualityFilter.checkFingerSignal(signal);

        qualityResult.passed = quality.passed;
        qualityResult.score  = quality.score;
        qualityResult.issue  = (PulseCoreQualityIssue)quality.issue;
        qualityResult.message =
            [NSString stringWithUTF8String:quality.message()];
    }
    
    if (mode == PulseCoreScanModeFace) {
        PulseCore::rPPGFrame frame =
            _rPPGProcessor.processFrame(bgrFrame, timestamp);

        if (!frame.isValid) {
            qualityResult.issue   = PulseCoreQualityIssueNotEnoughData;
            qualityResult.message = @"Hold still — calibrating...";
            return qualityResult;
        }

        qualityResult.passed = YES;
        qualityResult.score  = 0.8f;
        qualityResult.issue  = PulseCoreQualityIssueNone;
        qualityResult.message = @"Face detected — reading signal";
    }

    return qualityResult;
}

// ── Get full result ───────────────────────────────────────────────────────

- (PulseCoreResult*)currentResult {
    PulseCoreResult* result = [[PulseCoreResult alloc] init];
    result.isValid = NO;

    PulseCore::PPGSignal  fingerSignal = _ppgProcessor.getSignal();
    PulseCore::rPPGSignal faceSignal   = _rPPGProcessor.getSignal();

    // Determine which pipeline to use
    BOOL useFace   = faceSignal.hasEnoughData();
    BOOL useFinger = fingerSignal.hasEnoughData();
    
    
    result.isFromFaceScan = useFace;

    if (!useFace && !useFinger) return result;

    // Run appropriate signal processing pipeline
    PulseCore::SignalResult signalResult;

    if (useFace) {
        // rPPG-specific pipeline — relaxed thresholds
        signalResult = _signalProcessor.processRPPG(
            faceSignal.chrom, _sampleRate);
    } else {
        // Finger PPG pipeline — standard
        signalResult = _signalProcessor.process(
            fingerSignal.red, _sampleRate);
    }

    if (!signalResult.heartRate.isValid) return result;

    // Choose signal for glucose estimation
    std::vector<float> signalForGlucose = useFinger ?
        fingerSignal.red : faceSignal.chrom;

    // Run inference
    PulseCore::AFibResult afib =
        _afibDetector.analyse(signalResult.hrv.rrIntervals);

    PulseCore::GlucoseResult glucose =
        _glucoseEstimator.estimate(signalForGlucose, _sampleRate);

    PulseCore::StressRecoveryResult recovery = _stressScorer.compute(
        signalResult.hrv.rmssd,
        signalResult.hrv.sdnn,
        signalResult.heartRate.bpm,
        signalResult.breathing.breathsPerMinute
    );

    PulseCore::WellnessScore wellness = _wellnessScorer.compute(
        signalResult, afib, glucose, recovery
    );

    // Map to ObjC result
    result.isValid             = YES;
    result.heartRateBPM        = signalResult.heartRate.bpm;
    result.heartRateConfidence = signalResult.heartRate.confidence;
    result.rmssd               = signalResult.hrv.rmssd;
    result.sdnn                = signalResult.hrv.sdnn;
    result.breathingRate       = signalResult.breathing.breathsPerMinute;
    result.rhythmStatus        = (PulseCoreRhythmStatus)afib.status;
    result.afibConfidence      = afib.confidence;
    result.rhythmMessage       = [NSString stringWithUTF8String:
                                  afib.message()];
    result.glucoseTrend        = (PulseCoreGlucoseTrend)glucose.trend;
    result.glucoseConfidence   = glucose.confidence;
    result.glucoseMessage      = [NSString stringWithUTF8String:
                                  glucose.message()];
    result.recoveryScore       = recovery.score;
    result.recoveryLevel       = (PulseCoreRecoveryLevel)recovery.level;
    result.recoveryMessage     = [NSString stringWithUTF8String:
                                  recovery.message()];
    result.wellnessScore       = wellness.overallScore;
    result.wellnessMessage     = [NSString stringWithUTF8String:
                                  wellness.overallMessage()];

    return result;
}

// ── Progress ──────────────────────────────────────────────────────────────

- (float)scanProgress {
    double fingerDuration = _ppgProcessor.scanDuration();
    double faceDuration   = _rPPGProcessor.scanDuration();

    if (faceDuration > 0) {
        return MIN(static_cast<float>(faceDuration / 15.0), 1.0f);
    }
    return MIN(static_cast<float>(fingerDuration / 30.0), 1.0f);
}

- (NSArray<NSNumber*>*)recentSamples {
    PulseCore::PPGSignal signal = _ppgProcessor.getSignal();

    NSMutableArray* samples = [NSMutableArray array];
    size_t count = signal.red.size();
    size_t start = count > 100 ? count - 100 : 0;

    for (size_t i = start; i < count; i++) {
        [samples addObject:@(signal.red[i])];
    }
    return samples;
}

- (NSArray<NSNumber*>*)recentFaceSamples {
    PulseCore::rPPGSignal signal = _rPPGProcessor.getSignal();

    NSMutableArray* samples = [NSMutableArray array];
    size_t count = signal.chrom.size();
    size_t start = count > 100 ? count - 100 : 0;

    for (size_t i = start; i < count; i++) {
        [samples addObject:@(signal.chrom[i])];
    }
    return samples;
}


- (float)currentHeartRate {
    
    PulseCore::PPGSignal fingerSignal = _ppgProcessor.getSignal();
    if (fingerSignal.hasEnoughData()) {
        PulseCore::SignalResult result =
            _signalProcessor.process(fingerSignal.red, _sampleRate);
        if (result.heartRate.isValid) return result.heartRate.bpm;
    }

    // Try face signal
    PulseCore::rPPGSignal faceSignal = _rPPGProcessor.getSignal();
    if (faceSignal.chrom.size() >= 64) {
        PulseCore::SignalResult result =
            _signalProcessor.processRPPG(faceSignal.chrom, _sampleRate);
        if (result.heartRate.isValid) return result.heartRate.bpm;
    }
    return 0.0f;
}

- (float)currentRMSSD {
    PulseCore::PPGSignal signal = _ppgProcessor.getSignal();
    if (!signal.hasEnoughData()) return 0.0f;

    PulseCore::SignalResult result =
        _signalProcessor.process(signal.red, _sampleRate);

    if (result.hrv.isValid) {
        return result.hrv.rmssd;
    }
    return 0.0f;
}

- (float)currentBreathingRate {
    PulseCore::PPGSignal fingerSignal = _ppgProcessor.getSignal();
    if (fingerSignal.hasEnoughData()) {
        PulseCore::SignalResult result =
            _signalProcessor.process(fingerSignal.red, _sampleRate);
        if (result.breathing.isValid) return result.breathing.breathsPerMinute;
    }

    // Try face signal
    PulseCore::rPPGSignal faceSignal = _rPPGProcessor.getSignal();
    if (faceSignal.chrom.size() >= 64) {
        PulseCore::SignalResult result =
            _signalProcessor.processRPPG(faceSignal.chrom, _sampleRate);
        if (result.breathing.isValid) return result.breathing.breathsPerMinute;
    }

    return 0.0f;
}


- (BOOL)isReadyForResult {
    double duration = _ppgProcessor.scanDuration();
    return duration >= 30.0; // 28 real seconds
}
// ── Reset ─────────────────────────────────────────────────────────────────

- (void)reset {
    _ppgProcessor.reset();
    _rPPGProcessor.reset();
    _hasLastFrame   = NO;
    _frameCount     = 0;
    _firstTimestamp = 0.0;
}


@end
