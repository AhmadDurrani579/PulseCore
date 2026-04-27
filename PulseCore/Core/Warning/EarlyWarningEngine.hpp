//
//  EarlyWarningEngine.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include "WellnessScorer.hpp"
#include <vector>
#include <deque>

namespace PulseCore {

enum class WarningType {
    None,
    HRVDeclining,       // stress or illness building
    HeartRateElevated,  // consistently high resting HR
    BreathingElevated,  // persistent fast breathing
    RecoveryLow,        // body battery consistently low
    GlucoseRising,      // glucose trend upward multiple days
};

struct EarlyWarning {
    WarningType type;
    float severity;         // 0.0 - 1.0
    int daysOfTrend;        // how many days this trend detected
    bool isActive;

    const char* title() const {
        switch (type) {
            case WarningType::HRVDeclining:
                return "Recovery declining";
            case WarningType::HeartRateElevated:
                return "Resting heart rate elevated";
            case WarningType::BreathingElevated:
                return "Breathing rate elevated";
            case WarningType::RecoveryLow:
                return "Body battery consistently low";
            case WarningType::GlucoseRising:
                return "Glucose trend rising";
            default:
                return "All clear";
        }
    }

    const char* advice() const {
        switch (type) {
            case WarningType::HRVDeclining:
                return "Your body may be fighting something. Rest today and tomorrow.";
            case WarningType::HeartRateElevated:
                return "Consider reducing caffeine and stress today.";
            case WarningType::BreathingElevated:
                return "Try breathing exercises — 4 counts in, 4 counts out.";
            case WarningType::RecoveryLow:
                return "Prioritise sleep tonight. Avoid intense exercise.";
            case WarningType::GlucoseRising:
                return "Consider reducing sugar intake today.";
            default:
                return "Your vitals look stable. Keep it up.";
        }
    }
};

struct DailySnapshot {
    float wellnessScore;
    float hrvRMSSD;
    float heartRate;
    float breathingRate;
    float recoveryScore;
    GlucoseTrend glucoseTrend;
    double timestamp;
};

struct EarlyWarningResult {
    std::vector<EarlyWarning> warnings;
    bool hasActiveWarnings;
    float overallRisk;      // 0.0 - 1.0
    bool isValid;

    const char* summary() const {
        if (!hasActiveWarnings)
            return "Your body looks stable over the past few days";
        if (overallRisk > 0.7f)
            return "Multiple warning signs — prioritise rest today";
        return "Some early warning signs detected — take it easy";
    }
};

class EarlyWarningEngine {
public:
    EarlyWarningEngine();
    ~EarlyWarningEngine();

    // Add today's wellness snapshot
    void addSnapshot(const DailySnapshot& snapshot);

    // Analyse trends and generate warnings
    EarlyWarningResult analyse();

    // How many days of data do we have
    size_t dayCount() const;

    void reset();

private:
    std::deque<DailySnapshot> _history;

    EarlyWarning checkHRVTrend();
    EarlyWarning checkHeartRateTrend();
    EarlyWarning checkBreathingTrend();
    EarlyWarning checkRecoveryTrend();
    EarlyWarning checkGlucoseTrend();

    // Check if values are consistently declining
    bool isTrendDeclining(const std::vector<float>& values,
                           int minDays);

    // Check if values are consistently elevated
    bool isTrendElevated(const std::vector<float>& values,
                          float threshold,
                          int minDays);

    static constexpr size_t kMinDays        = 3;
    static constexpr size_t kMaxDays        = 30;
    static constexpr float  kHRVDropThresh  = 0.15f; // 15% drop
    static constexpr float  kHRHighThresh   = 85.0f; // BPM
    static constexpr float  kBreathThresh   = 18.0f; // breaths/min
    static constexpr float  kRecoveryThresh = 35.0f; // score
};

} // namespace PulseCore
