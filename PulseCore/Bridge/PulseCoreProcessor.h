//
//  PulseCoreProcessor.h
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>



NS_ASSUME_NONNULL_BEGIN

// Scan mode
typedef NS_ENUM(NSInteger, PulseCoreScanMode) {
    PulseCoreScanModeFinger = 0,
    PulseCoreScanModeFace   = 1
};

// Quality issue
typedef NS_ENUM(NSInteger, PulseCoreQualityIssue) {
    PulseCoreQualityIssueNone           = 0,
    PulseCoreQualityIssueSignalTooWeak  = 1,
    PulseCoreQualityIssueMotionDetected = 2,
    PulseCoreQualityIssueNotEnoughData  = 3,
    PulseCoreQualityIssueLowSNR         = 4
};

// Rhythm status
typedef NS_ENUM(NSInteger, PulseCoreRhythmStatus) {
    PulseCoreRhythmStatusNormal       = 0,
    PulseCoreRhythmStatusIrregular    = 1,
    PulseCoreRhythmStatusInconclusive = 2
};

// Glucose trend
typedef NS_ENUM(NSInteger, PulseCoreGlucoseTrend) {
    PulseCoreGlucoseTrendRising       = 0,
    PulseCoreGlucoseTrendFalling      = 1,
    PulseCoreGlucoseTrendStable       = 2,
    PulseCoreGlucoseTrendInconclusive = 3
};

// Recovery level
typedef NS_ENUM(NSInteger, PulseCoreRecoveryLevel) {
    PulseCoreRecoveryLevelPeak     = 0,
    PulseCoreRecoveryLevelGood     = 1,
    PulseCoreRecoveryLevelModerate = 2,
    PulseCoreRecoveryLevelLow      = 3,
    PulseCoreRecoveryLevelDepleted = 4
};

// Quality result
@interface PulseCoreQualityResult : NSObject
@property (nonatomic) BOOL passed;
@property (nonatomic) float score;
@property (nonatomic) PulseCoreQualityIssue issue;
@property (nonatomic, strong) NSString* message;
@end

// Full scan result
@interface PulseCoreResult : NSObject
@property (nonatomic) BOOL isValid;

// Heart
@property (nonatomic) float heartRateBPM;
@property (nonatomic) float heartRateConfidence;

// HRV
@property (nonatomic) float rmssd;
@property (nonatomic) float sdnn;

// Breathing
@property (nonatomic) float breathingRate;

// AFib
@property (nonatomic) PulseCoreRhythmStatus rhythmStatus;
@property (nonatomic) float afibConfidence;
@property (nonatomic, strong) NSString* rhythmMessage;

// Glucose
@property (nonatomic) PulseCoreGlucoseTrend glucoseTrend;
@property (nonatomic) float glucoseConfidence;
@property (nonatomic, strong) NSString* glucoseMessage;

// Recovery
@property (nonatomic) float recoveryScore;
@property (nonatomic) PulseCoreRecoveryLevel recoveryLevel;
@property (nonatomic, strong) NSString* recoveryMessage;

// Wellness
@property (nonatomic) float wellnessScore;
@property (nonatomic, strong) NSString* wellnessMessage;


@property (nonatomic) BOOL isFromFaceScan;

@end

// Main processor — ObjC interface to C++ engine
@interface PulseCoreProcessor : NSObject

- (instancetype)init;

// Feed camera frame in
- (PulseCoreQualityResult*)processSampleBuffer:(CMSampleBufferRef)buffer
                                          mode:(PulseCoreScanMode)mode;

// Get full result when scan is complete
- (PulseCoreResult*)currentResult;

// Progress 0.0 - 1.0
- (float)scanProgress;

// Is there enough data for a result
- (BOOL)isReadyForResult;

// Reset for new scan
- (void)reset;

- (float)currentHeartRate;
- (float)currentRMSSD;
- (float)currentBreathingRate;

- (NSArray<NSNumber*>*)recentSamples;
- (NSArray<NSNumber*>*)recentFaceSamples;


@end

NS_ASSUME_NONNULL_END
