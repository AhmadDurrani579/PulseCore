//
//  QualityFilter.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include "PPGProcessor.hpp"
#include <vector>

namespace PulseCore {

enum class QualityIssue {
    None,
    SignalTooWeak,      // finger not covering camera
    MotionDetected,     // finger moving too much
    NotEnoughData,      // less than 1 second of data
    LowSNR              // signal buried in noise
};

struct QualityResult {
    bool passed;
    float score;        // 0.0 - 1.0
    QualityIssue issue;

    // Human readable message for UI
    const char* message() const {
        switch (issue) {
            case QualityIssue::None:
                return "Signal good";
            case QualityIssue::SignalTooWeak:
                return "Press finger firmly on camera";
            case QualityIssue::MotionDetected:
                return "Keep your finger still";
            case QualityIssue::NotEnoughData:
                return "Hold still...";
            case QualityIssue::LowSNR:
                return "Cover the camera completely";
            default:
                return "Adjusting...";
        }
    }
};

class QualityFilter {
public:
    QualityFilter();
    ~QualityFilter();

    // Check finger PPG signal quality
    QualityResult checkFingerSignal(const PPGSignal& signal);

    // Check single incoming frame for motion
    bool hasMotion(const PPGFrame& current,
                   const PPGFrame& previous);

private:
    float computeSNR(const std::vector<float>& signal);
    float computeMotionScore(const PPGFrame& current,
                             const PPGFrame& previous);

    // Thresholds
    static constexpr float kMinSNR          = 2.0f;
    static constexpr float kMinVariance     = 5.0f;
    static constexpr float kMaxMotionDelta  = 25.0f;
    static constexpr float kMinSeconds      = 1.0f;
};

} // namespace PulseCore
