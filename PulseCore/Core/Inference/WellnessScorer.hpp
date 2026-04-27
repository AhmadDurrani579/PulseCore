//
//  WellnessScorer.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include "AFibDetector.hpp"
#include "GlucoseEstimator.hpp"
#include "StressRecoveryScore.hpp"
#include "../Signal/SignalProcessor.hpp"

namespace PulseCore {

struct WellnessScore {
    // Individual scores
    float heartScore;       // 0-100 heart health
    float recoveryScore;    // 0-100 body battery
    float breathingScore;   // 0-100 breathing quality
    float overallScore;     // 0-100 overall wellness

    // Results from each engine
    AFibResult          afib;
    GlucoseResult       glucose;
    StressRecoveryResult recovery;
    SignalResult        signal;

    // Overall wellness level
    bool isValid;

    const char* overallMessage() const {
        if (overallScore >= 80.0f)
            return "You are in great shape today";
        if (overallScore >= 60.0f)
            return "You are doing well — keep it up";
        if (overallScore >= 40.0f)
            return "Some signs of fatigue — take it easy";
        if (overallScore >= 20.0f)
            return "Your body needs rest today";
        return "Prioritise recovery — sleep and rest";
    }
};

class WellnessScorer {
public:
    WellnessScorer();
    ~WellnessScorer();

    // Fuse all results into one wellness score
    WellnessScore compute(const SignalResult&        signal,
                           const AFibResult&          afib,
                           const GlucoseResult&       glucose,
                           const StressRecoveryResult& recovery);

private:
    float computeHeartScore(const SignalResult& signal,
                             const AFibResult& afib);

    float computeBreathingScore(const BreathingResult& breathing);

    float computeOverallScore(float heartScore,
                               float recoveryScore,
                               float breathingScore);
};

} // namespace PulseCore
