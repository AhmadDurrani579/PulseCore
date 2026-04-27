//
//  WellnessScorer.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "WellnessScorer.hpp"
#include <cmath>
#include <algorithm>

namespace PulseCore {

WellnessScorer::WellnessScorer() {}
WellnessScorer::~WellnessScorer() {}

WellnessScore WellnessScorer::compute(
    const SignalResult&         signal,
    const AFibResult&           afib,
    const GlucoseResult&        glucose,
    const StressRecoveryResult& recovery) {

    WellnessScore result;
    result.isValid = false;

    // Store all individual results
    result.signal   = signal;
    result.afib     = afib;
    result.glucose  = glucose;
    result.recovery = recovery;

    // Need at least heart rate to compute anything
    if (!signal.heartRate.isValid) return result;

    // Step 1 — compute individual scores
    result.heartScore    = computeHeartScore(signal, afib);
    result.recoveryScore = recovery.isValid ? recovery.score : 50.0f;
    result.breathingScore = computeBreathingScore(signal.breathing);

    // Step 2 — fuse into overall score
    result.overallScore = computeOverallScore(
        result.heartScore,
        result.recoveryScore,
        result.breathingScore
    );

    result.isValid = true;
    return result;
}

// ── Heart score ───────────────────────────────────────────────────────────

float WellnessScorer::computeHeartScore(const SignalResult& signal,
                                         const AFibResult& afib) {
    float score = 100.0f;

    // Heart rate contribution
    if (signal.heartRate.isValid) {
        float bpm = signal.heartRate.bpm;

        // Optimal resting: 50-80 BPM
        if (bpm >= 50.0f && bpm <= 80.0f) {
            score = 100.0f;
        } else if (bpm > 80.0f && bpm <= 100.0f) {
            // Mildly elevated — small penalty
            score -= (bpm - 80.0f) * 1.5f;
        } else if (bpm > 100.0f) {
            // Significantly elevated
            score -= 30.0f + (bpm - 100.0f) * 2.0f;
        } else if (bpm < 50.0f) {
            // Very low — could be athlete or concern
            score -= (50.0f - bpm) * 1.0f;
        }
    }

    // HRV contribution
    if (signal.hrv.isValid) {
        // Good RMSSD > 30ms at rest
        if (signal.hrv.rmssd < 20.0f) {
            score -= 20.0f;
        } else if (signal.hrv.rmssd < 30.0f) {
            score -= 10.0f;
        }
    }

    // AFib penalty — significant if irregular
    if (afib.isValid) {
        if (afib.status == RhythmStatus::Irregular) {
            score -= 40.0f;
        } else if (afib.status == RhythmStatus::Inconclusive) {
            score -= 10.0f;
        }
    }

    return std::max(0.0f, std::min(score, 100.0f));
}

// ── Breathing score ───────────────────────────────────────────────────────

float WellnessScorer::computeBreathingScore(
    const BreathingResult& breathing) {

    if (!breathing.isValid) return 50.0f; // neutral if no data

    float bpm   = breathing.breathsPerMinute;
    float score = 100.0f;

    // Optimal: 12-16 breaths/min
    if (bpm >= 12.0f && bpm <= 16.0f) {
        score = 100.0f;
    } else if (bpm > 16.0f && bpm <= 20.0f) {
        // Mildly elevated
        score -= (bpm - 16.0f) * 5.0f;
    } else if (bpm > 20.0f) {
        // High — stress indicator
        score -= 20.0f + (bpm - 20.0f) * 3.0f;
    } else if (bpm < 12.0f && bpm >= 8.0f) {
        // Slightly low — relaxed
        score = 90.0f;
    } else if (bpm < 8.0f) {
        // Very low — inconclusive
        score = 50.0f;
    }

    return std::max(0.0f, std::min(score, 100.0f));
}

// ── Overall score ─────────────────────────────────────────────────────────

float WellnessScorer::computeOverallScore(float heartScore,
                                           float recoveryScore,
                                           float breathingScore) {
    // Weighted fusion
    // Heart health carries most weight
    // Recovery (HRV-based) second
    // Breathing third
    float overall = (heartScore    * 0.45f)
                  + (recoveryScore * 0.35f)
                  + (breathingScore * 0.20f);

    return std::max(0.0f, std::min(overall, 100.0f));
}

} // namespace PulseCore
