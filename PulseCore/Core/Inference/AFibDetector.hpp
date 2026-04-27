//
//  AFibDetector.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include <vector>

namespace PulseCore {

enum class RhythmStatus {
    Normal,           // regular rhythm
    Irregular,        // possible AFib
    Inconclusive,     // not enough data
};

struct AFibResult {
    RhythmStatus status;
    float entropyScore;     // 0.0 - 1.0, higher = more irregular
    float irregularityScore;// 0.0 - 1.0, higher = more irregular
    float confidence;       // 0.0 - 1.0
    bool isValid;

    // Human readable message for UI
    const char* message() const {
        switch (status) {
            case RhythmStatus::Normal:
                return "Normal rhythm detected";
            case RhythmStatus::Irregular:
                return "Irregular rhythm — consider seeing a doctor";
            case RhythmStatus::Inconclusive:
                return "Not enough data for rhythm analysis";
            default:
                return "Analysing...";
        }
    }
};

class AFibDetector {
public:
    AFibDetector();
    ~AFibDetector();

    // Takes RR intervals in milliseconds from SignalProcessor
    AFibResult analyse(const std::vector<float>& rrIntervals);

private:
    // Shannon entropy of RR interval histogram
    float computeEntropy(const std::vector<float>& rrIntervals);

    // RMSSD-based irregularity
    float computeIrregularity(const std::vector<float>& rrIntervals);

    // Coefficient of variation
    float computeCV(const std::vector<float>& rrIntervals);

    // Thresholds
    static constexpr size_t kMinIntervals  = 3;
    static constexpr float  kEntropyThresh = 0.85f;
    static constexpr float  kIrregThresh   = 0.25f;
    static constexpr float  kCVThresh      = 0.18f;
};

} // namespace PulseCore
