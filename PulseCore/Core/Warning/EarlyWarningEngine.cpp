//
//  EarlyWarningEngine.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "EarlyWarningEngine.hpp"
#include <cmath>
#include <numeric>
#include <algorithm>

namespace PulseCore {

EarlyWarningEngine::EarlyWarningEngine() {}
EarlyWarningEngine::~EarlyWarningEngine() {}

void EarlyWarningEngine::addSnapshot(const DailySnapshot& snapshot) {
    _history.push_back(snapshot);
    if (_history.size() > kMaxDays) {
        _history.pop_front();
    }
}

EarlyWarningResult EarlyWarningEngine::analyse() {
    EarlyWarningResult result;
    result.isValid           = false;
    result.hasActiveWarnings = false;
    result.overallRisk       = 0.0f;

    if (_history.size() < kMinDays) return result;

    // Run all trend checks
    EarlyWarning hrvWarning      = checkHRVTrend();
    EarlyWarning hrWarning       = checkHeartRateTrend();
    EarlyWarning breathWarning   = checkBreathingTrend();
    EarlyWarning recoveryWarning = checkRecoveryTrend();
    EarlyWarning glucoseWarning  = checkGlucoseTrend();

    // Collect active warnings
    std::vector<EarlyWarning> allWarnings = {
        hrvWarning,
        hrWarning,
        breathWarning,
        recoveryWarning,
        glucoseWarning
    };

    for (const auto& warning : allWarnings) {
        if (warning.isActive) {
            result.warnings.push_back(warning);
            result.hasActiveWarnings = true;
            result.overallRisk += warning.severity;
        }
    }

    // Normalise overall risk to 0-1
    if (!result.warnings.empty()) {
        result.overallRisk /= result.warnings.size();
        result.overallRisk  = std::min(result.overallRisk, 1.0f);
    }

    result.isValid = true;
    return result;
}

// ── HRV trend ─────────────────────────────────────────────────────────────

EarlyWarning EarlyWarningEngine::checkHRVTrend() {
    EarlyWarning warning;
    warning.type     = WarningType::HRVDeclining;
    warning.isActive = false;
    warning.severity = 0.0f;

    std::vector<float> hrvValues;
    for (const auto& snap : _history) {
        if (snap.hrvRMSSD > 0.0f) {
            hrvValues.push_back(snap.hrvRMSSD);
        }
    }

    if (hrvValues.size() < kMinDays) return warning;

    // Check if HRV is consistently declining
    if (!isTrendDeclining(hrvValues, kMinDays)) return warning;

    // Compute how much it dropped
    float firstValue = hrvValues.front();
    float lastValue  = hrvValues.back();

    if (firstValue < 1e-6f) return warning;

    float dropPercent = (firstValue - lastValue) / firstValue;

    if (dropPercent >= kHRVDropThresh) {
        warning.isActive    = true;
        warning.severity    = std::min(dropPercent / 0.4f, 1.0f);
        warning.daysOfTrend = static_cast<int>(hrvValues.size());
    }

    return warning;
}

// ── Heart rate trend ──────────────────────────────────────────────────────

EarlyWarning EarlyWarningEngine::checkHeartRateTrend() {
    EarlyWarning warning;
    warning.type     = WarningType::HeartRateElevated;
    warning.isActive = false;
    warning.severity = 0.0f;

    std::vector<float> hrValues;
    for (const auto& snap : _history) {
        if (snap.heartRate > 0.0f) {
            hrValues.push_back(snap.heartRate);
        }
    }

    if (hrValues.size() < kMinDays) return warning;

    if (isTrendElevated(hrValues, kHRHighThresh, kMinDays)) {
        float meanHR = std::accumulate(hrValues.begin(),
                                        hrValues.end(), 0.0f)
                       / hrValues.size();

        warning.isActive    = true;
        warning.severity    = std::min(
                                (meanHR - kHRHighThresh) / 30.0f, 1.0f);
        warning.daysOfTrend = static_cast<int>(hrValues.size());
    }

    return warning;
}

// ── Breathing trend ───────────────────────────────────────────────────────

EarlyWarning EarlyWarningEngine::checkBreathingTrend() {
    EarlyWarning warning;
    warning.type     = WarningType::BreathingElevated;
    warning.isActive = false;
    warning.severity = 0.0f;

    std::vector<float> breathValues;
    for (const auto& snap : _history) {
        if (snap.breathingRate > 0.0f) {
            breathValues.push_back(snap.breathingRate);
        }
    }

    if (breathValues.size() < kMinDays) return warning;

    if (isTrendElevated(breathValues, kBreathThresh, kMinDays)) {
        float meanBreath = std::accumulate(breathValues.begin(),
                                            breathValues.end(), 0.0f)
                           / breathValues.size();

        warning.isActive    = true;
        warning.severity    = std::min(
                                (meanBreath - kBreathThresh) / 10.0f, 1.0f);
        warning.daysOfTrend = static_cast<int>(breathValues.size());
    }

    return warning;
}

// ── Recovery trend ────────────────────────────────────────────────────────

EarlyWarning EarlyWarningEngine::checkRecoveryTrend() {
    EarlyWarning warning;
    warning.type     = WarningType::RecoveryLow;
    warning.isActive = false;
    warning.severity = 0.0f;

    std::vector<float> recoveryValues;
    for (const auto& snap : _history) {
        if (snap.recoveryScore > 0.0f) {
            recoveryValues.push_back(snap.recoveryScore);
        }
    }

    if (recoveryValues.size() < kMinDays) return warning;

    // Check if consistently below threshold
    int lowCount = 0;
    for (float score : recoveryValues) {
        if (score < kRecoveryThresh) lowCount++;
    }

    if (lowCount >= static_cast<int>(kMinDays)) {
        float meanRecovery = std::accumulate(recoveryValues.begin(),
                                              recoveryValues.end(), 0.0f)
                             / recoveryValues.size();

        warning.isActive    = true;
        warning.severity    = std::min(
                                (kRecoveryThresh - meanRecovery)
                                / kRecoveryThresh, 1.0f);
        warning.daysOfTrend = lowCount;
    }

    return warning;
}

// ── Glucose trend ─────────────────────────────────────────────────────────

EarlyWarning EarlyWarningEngine::checkGlucoseTrend() {
    EarlyWarning warning;
    warning.type     = WarningType::GlucoseRising;
    warning.isActive = false;
    warning.severity = 0.0f;

    // Count consecutive Rising glucose readings
    int risingCount = 0;
    for (const auto& snap : _history) {
        if (snap.glucoseTrend == GlucoseTrend::Rising) {
            risingCount++;
        } else if (snap.glucoseTrend == GlucoseTrend::Stable) {
            // Stable doesn't break the streak
        } else {
            risingCount = 0; // reset on Falling or Inconclusive
        }
    }

    if (risingCount >= static_cast<int>(kMinDays)) {
        warning.isActive    = true;
        warning.severity    = std::min(
                                static_cast<float>(risingCount) / 7.0f,
                                1.0f);
        warning.daysOfTrend = risingCount;
    }

    return warning;
}

// ── Trend helpers ─────────────────────────────────────────────────────────

bool EarlyWarningEngine::isTrendDeclining(
    const std::vector<float>& values, int minDays) {

    if (static_cast<int>(values.size()) < minDays) return false;

    // Check last minDays values are each lower than previous
    size_t start = values.size() - minDays;
    int decliningCount = 0;

    for (size_t i = start + 1; i < values.size(); i++) {
        if (values[i] < values[i - 1]) {
            decliningCount++;
        }
    }

    // Need 2/3 of days to be declining
    return decliningCount >= (minDays - 1);
}

bool EarlyWarningEngine::isTrendElevated(
    const std::vector<float>& values,
    float threshold,
    int minDays) {

    if (static_cast<int>(values.size()) < minDays) return false;

    // Count how many of last minDays values exceed threshold
    size_t start     = values.size() - minDays;
    int elevatedCount = 0;

    for (size_t i = start; i < values.size(); i++) {
        if (values[i] > threshold) {
            elevatedCount++;
        }
    }

    // All minDays must be elevated
    return elevatedCount >= minDays;
}

size_t EarlyWarningEngine::dayCount() const {
    return _history.size();
}

void EarlyWarningEngine::reset() {
    _history.clear();
}

} // namespace PulseCore
