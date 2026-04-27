//
//  StressRecoveryScore.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include <vector>

namespace PulseCore {

enum class RecoveryLevel {
    Peak,        // 80-100 — fully recovered
    Good,        // 60-79  — ready for normal activity
    Moderate,    // 40-59  — some fatigue
    Low,         // 20-39  — needs rest
    Depleted     // 0-19   — significant recovery needed
};

struct StressRecoveryResult {
    float score;              // 0.0 - 100.0
    RecoveryLevel level;
    float hrvContribution;    // how much HRV influenced score
    float stressContribution; // how much stress influenced score
    bool isValid;

    const char* message() const {
        switch (level) {
            case RecoveryLevel::Peak:
                return "Peak condition — your body is fully recovered";
            case RecoveryLevel::Good:
                return "Good recovery — ready for normal activity";
            case RecoveryLevel::Moderate:
                return "Moderate fatigue — light activity recommended";
            case RecoveryLevel::Low:
                return "Low battery — your body needs rest today";
            case RecoveryLevel::Depleted:
                return "Depleted — prioritise sleep and recovery";
            default:
                return "Analysing recovery...";
        }
    }

    const char* levelLabel() const {
        switch (level) {
            case RecoveryLevel::Peak:      return "Peak";
            case RecoveryLevel::Good:      return "Good";
            case RecoveryLevel::Moderate:  return "Moderate";
            case RecoveryLevel::Low:       return "Low";
            case RecoveryLevel::Depleted:  return "Depleted";
            default:                       return "Unknown";
        }
    }
};

class StressRecoveryScore {
public:
    StressRecoveryScore();
    ~StressRecoveryScore();

    // Takes HRV metrics from SignalProcessor
    StressRecoveryResult compute(float rmssd,
                                  float sdnn,
                                  float heartRateBPM,
                                  float breathingRate);

private:
    // Normalise RMSSD to 0-100
    float normaliseRMSSD(float rmssd);

    // Normalise SDNN to 0-100
    float normaliseSDNN(float sdnn);

    // Heart rate penalty — elevated HR reduces score
    float heartRatePenalty(float bpm);

    // Breathing rate contribution
    float breathingContribution(float breathsPerMin);

    // Determine level from score
    RecoveryLevel scoreToLevel(float score);

    // Reference ranges (population averages)
    static constexpr float kRMSSDLow      = 15.0f;  // ms — depleted
    static constexpr float kRMSSDHigh     = 80.0f;  // ms — peak
    static constexpr float kSDNNLow       = 20.0f;  // ms — depleted
    static constexpr float kSDNNHigh      = 100.0f; // ms — peak
    static constexpr float kRestingHRHigh = 100.0f; // BPM — penalty starts
    static constexpr float kRestingHRLow  = 45.0f;  // BPM — athlete range
    static constexpr float kBreathLow     = 8.0f;   // breaths/min
    static constexpr float kBreathHigh    = 20.0f;  // breaths/min
};

} // namespace PulseCore
