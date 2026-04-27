//
//  GlucoseEstimator.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include <vector>

namespace PulseCore {

enum class GlucoseTrend {
    Rising,        // glucose going up
    Falling,       // glucose going down
    Stable,        // glucose steady
    Inconclusive   // not enough data
};

struct GlucoseResult {
    GlucoseTrend trend;
    float confidence;       // 0.0 - 1.0
    float riseTime;         // pulse wave rise time ms
    float peakWidth;        // pulse wave width at peak ms
    float augmentationIndex;// waveform reflection index
    bool isValid;

    const char* message() const {
        switch (trend) {
            case GlucoseTrend::Rising:
                return "Glucose trending up — consider eating soon";
            case GlucoseTrend::Falling:
                return "Glucose trending down — levels stabilising";
            case GlucoseTrend::Stable:
                return "Glucose appears stable";
            case GlucoseTrend::Inconclusive:
                return "Not enough data for glucose estimate";
            default:
                return "Analysing...";
        }
    }
};

class GlucoseEstimator {
public:
    GlucoseEstimator();
    ~GlucoseEstimator();

    // Takes filtered PPG signal + sample rate
    GlucoseResult estimate(const std::vector<float>& signal,
                            float sampleRate);

private:
    // Waveform shape features
    float computeRiseTime(const std::vector<float>& pulse,
                           float sampleRate);
    float computePeakWidth(const std::vector<float>& pulse,
                            float sampleRate);
    float computeAugmentationIndex(const std::vector<float>& pulse);

    // Extract single pulse wave around a peak
    std::vector<float> extractPulse(const std::vector<float>& signal,
                                     size_t peakIndex,
                                     float sampleRate);

    // Find peaks in signal
    std::vector<size_t> findPeaks(const std::vector<float>& signal,
                                   float minDistance);

    // Thresholds
    static constexpr float kHighRiseTime  = 120.0f; // ms — high glucose
    static constexpr float kLowRiseTime   = 80.0f;  // ms — low glucose
    static constexpr float kMinPeaks      = 3;
};

} // namespace PulseCore
