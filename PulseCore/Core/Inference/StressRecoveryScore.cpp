//
//  StressRecoveryScore.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "StressRecoveryScore.hpp"
#include <cmath>
#include <algorithm>

namespace PulseCore {

StressRecoveryScore::StressRecoveryScore() {}
StressRecoveryScore::~StressRecoveryScore() {}

StressRecoveryResult StressRecoveryScore::compute(float rmssd,
                                                   float sdnn,
                                                   float heartRateBPM,
                                                   float breathingRate) {
    StressRecoveryResult result;
    result.isValid = false;

    if (rmssd <= 0.0f || sdnn <= 0.0f || heartRateBPM <= 0.0f) {
        return result;
    }

    // Step 1 — normalise each metric to 0-100
    float rmssdScore    = normaliseRMSSD(rmssd);
    float sdnnScore     = normaliseSDNN(sdnn);
    float hrPenalty     = heartRatePenalty(heartRateBPM);
    float breathScore   = breathingContribution(breathingRate);

    // Step 2 — weighted combination
    // HRV metrics carry the most weight
    // Heart rate and breathing fine-tune the score
    float rawScore = (rmssdScore    * 0.40f)  // 40% weight
                   + (sdnnScore     * 0.30f)  // 30% weight
                   + (breathScore   * 0.20f)  // 20% weight
                   - (hrPenalty     * 0.10f); // 10% penalty

    // Step 3 — clamp to 0-100
    result.score = std::max(0.0f, std::min(rawScore, 100.0f));
    result.level = scoreToLevel(result.score);

    // Record contributions for UI transparency
    result.hrvContribution    = (rmssdScore * 0.40f + sdnnScore * 0.30f);
    result.stressContribution = hrPenalty * 0.10f;
    result.isValid            = true;

    return result;
}

// ── Normalise RMSSD ───────────────────────────────────────────────────────

float StressRecoveryScore::normaliseRMSSD(float rmssd) {
    // RMSSD population range: 15ms (depleted) to 80ms (peak)
    // Map linearly to 0-100
    float normalised = (rmssd - kRMSSDLow) /
                       (kRMSSDHigh - kRMSSDLow) * 100.0f;
    return std::max(0.0f, std::min(normalised, 100.0f));
}

// ── Normalise SDNN ────────────────────────────────────────────────────────

float StressRecoveryScore::normaliseSDNN(float sdnn) {
    // SDNN population range: 20ms (depleted) to 100ms (peak)
    float normalised = (sdnn - kSDNNLow) /
                       (kSDNNHigh - kSDNNLow) * 100.0f;
    return std::max(0.0f, std::min(normalised, 100.0f));
}

// ── Heart rate penalty ────────────────────────────────────────────────────

float StressRecoveryScore::heartRatePenalty(float bpm) {
    // Elevated resting heart rate = poor recovery
    // Normal resting: 60-80 BPM
    // Penalty kicks in above 80 BPM

    if (bpm <= 80.0f) return 0.0f;

    // Linear penalty from 80-100 BPM
    float penalty = (bpm - 80.0f) / (kRestingHRHigh - 80.0f) * 100.0f;
    return std::max(0.0f, std::min(penalty, 100.0f));
}

// ── Breathing contribution ────────────────────────────────────────────────

float StressRecoveryScore::breathingContribution(float breathsPerMin) {
    // Normal breathing at rest: 12-16 breaths/min
    // Too fast (>20) = stress, too slow (<8) = inconclusive

    if (breathsPerMin <= 0.0f) return 50.0f; // neutral if no data

    if (breathsPerMin >= kBreathLow && breathsPerMin <= 16.0f) {
        // Optimal range
        return 100.0f;
    } else if (breathsPerMin > 16.0f && breathsPerMin <= kBreathHigh) {
        // Slightly elevated — linear decrease
        float score = 100.0f - ((breathsPerMin - 16.0f) /
                                 (kBreathHigh - 16.0f)) * 50.0f;
        return std::max(0.0f, score);
    } else if (breathsPerMin > kBreathHigh) {
        // High breathing rate = significant stress
        return 0.0f;
    }

    return 50.0f; // below normal range — neutral
}

// ── Score to level ────────────────────────────────────────────────────────

RecoveryLevel StressRecoveryScore::scoreToLevel(float score) {
    if (score >= 80.0f) return RecoveryLevel::Peak;
    if (score >= 60.0f) return RecoveryLevel::Good;
    if (score >= 40.0f) return RecoveryLevel::Moderate;
    if (score >= 20.0f) return RecoveryLevel::Low;
    return RecoveryLevel::Depleted;
}

} // namespace PulseCore
