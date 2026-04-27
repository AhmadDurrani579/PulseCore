//
//  CalibrationEngine.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "CalibrationEngine.hpp"
#include <cmath>
#include <numeric>
#include <algorithm>

namespace PulseCore {

CalibrationEngine::CalibrationEngine() {
    _profile.heartRateCorrectionFactor = 1.0f;
    _profile.rmssdCorrectionFactor     = 1.0f;
    _profile.redChannelWeight          = 1.0f;
    _profile.greenChannelWeight        = 1.0f;
    _profile.blueChannelWeight         = 1.0f;
    _profile.sampleCount               = 0;
    _profile.isCalibrated              = false;
}

CalibrationEngine::~CalibrationEngine() {}

void CalibrationEngine::addSample(const CalibrationSample& sample) {
    // Sanity check — both readings must be valid
    if (sample.fingerHeartRate <= 0.0f ||
        sample.faceHeartRate   <= 0.0f) return;

    // Add to rolling buffer
    _samples.push_back(sample);
    if (_samples.size() > kMaxSamples) {
        _samples.pop_front();
    }

    // Recompute profile after every new sample
    recomputeProfile();
}

// ── Apply calibration ─────────────────────────────────────────────────────

float CalibrationEngine::calibrateHeartRate(float rawFaceHR) const {
    if (!_profile.isCalibrated) return rawFaceHR;
    return rawFaceHR * _profile.heartRateCorrectionFactor;
}

float CalibrationEngine::calibrateRMSSD(float rawFaceRMSSD) const {
    if (!_profile.isCalibrated) return rawFaceRMSSD;
    return rawFaceRMSSD * _profile.rmssdCorrectionFactor;
}

// ── Recompute profile ─────────────────────────────────────────────────────

void CalibrationEngine::recomputeProfile() {
    if (_samples.size() < kMinSamples) return;

    // Compute average ratio: finger / face for heart rate
    std::vector<float> hrRatios;
    std::vector<float> rmssdRatios;

    for (const auto& sample : _samples) {
        if (sample.faceHeartRate > 0.0f) {
            float hrRatio = sample.fingerHeartRate /
                            sample.faceHeartRate;
            // Sanity check — ratio should be close to 1.0
            // Reject outliers beyond 30% deviation
            if (hrRatio >= 0.7f && hrRatio <= 1.3f) {
                hrRatios.push_back(hrRatio);
            }
        }

        if (sample.faceRMSSD > 0.0f) {
            float rmssdRatio = sample.fingerRMSSD /
                               sample.faceRMSSD;
            if (rmssdRatio >= 0.5f && rmssdRatio <= 2.0f) {
                rmssdRatios.push_back(rmssdRatio);
            }
        }
    }

    // Update correction factors using weighted average
    // Recent samples weighted more than older ones
    if (!hrRatios.empty()) {
        float weightedSum = 0.0f;
        float totalWeight = 0.0f;

        for (size_t i = 0; i < hrRatios.size(); i++) {
            // More recent = higher weight
            float weight = static_cast<float>(i + 1);
            weightedSum += hrRatios[i] * weight;
            totalWeight += weight;
        }

        _profile.heartRateCorrectionFactor = weightedSum / totalWeight;
    }

    if (!rmssdRatios.empty()) {
        float weightedSum = 0.0f;
        float totalWeight = 0.0f;

        for (size_t i = 0; i < rmssdRatios.size(); i++) {
            float weight = static_cast<float>(i + 1);
            weightedSum += rmssdRatios[i] * weight;
            totalWeight += weight;
        }

        _profile.rmssdCorrectionFactor = weightedSum / totalWeight;
    }

    _profile.sampleCount  = _samples.size();
    _profile.isCalibrated = _samples.size() >= kMinSamples;
}

// ── Calibration confidence ────────────────────────────────────────────────

float CalibrationEngine::calibrationConfidence() const {
    if (_samples.size() < kMinSamples) {
        return static_cast<float>(_samples.size()) /
               static_cast<float>(kMinSamples);
    }

    // Full confidence after kFullCalibration samples
    float confidence = static_cast<float>(_samples.size()) /
                       static_cast<float>(kFullCalibration);

    return std::min(confidence, 1.0f);
}

CalibrationProfile CalibrationEngine::getProfile() const {
    return _profile;
}

void CalibrationEngine::reset() {
    _samples.clear();
    _profile.heartRateCorrectionFactor = 1.0f;
    _profile.rmssdCorrectionFactor     = 1.0f;
    _profile.sampleCount               = 0;
    _profile.isCalibrated              = false;
}

} // namespace PulseCore
