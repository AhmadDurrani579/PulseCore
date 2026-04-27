//
//  QualityFilter.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "QualityFilter.hpp"
#include <numeric>
#include <cmath>
#include <algorithm>

namespace PulseCore {

QualityFilter::QualityFilter() {}
QualityFilter::~QualityFilter() {}

QualityResult QualityFilter::checkFingerSignal(const PPGSignal& signal) {
    QualityResult result;
    result.passed = false;
    result.score  = 0.0f;
    result.issue  = QualityIssue::None;

    float fps = 30.0f; // default fallback
    if (signal.timestamps.size() >= 2) {
        double duration = signal.timestamps.back() - signal.timestamps.front();
        fps = static_cast<float>(signal.timestamps.size()) / duration;
    }

    size_t minSamples = static_cast<size_t>(fps * kMinSeconds);

    if (signal.red.size() < minSamples) {
        result.issue = QualityIssue::NotEnoughData;
        result.score = static_cast<float>(signal.red.size()) / minSamples;
        return result;
    }

    // Check 2 — signal variance (finger covering camera)
    float mean = std::accumulate(signal.red.begin(),
                                 signal.red.end(), 0.0f) / signal.red.size();

    float variance = 0.0f;
    for (float v : signal.red) {
        variance += (v - mean) * (v - mean);
    }
    variance /= signal.red.size();

    if (variance < kMinVariance) {
        result.issue = QualityIssue::SignalTooWeak;
        result.score = variance / kMinVariance;
        return result;
    }

    // Check 3 — SNR
    float snr = computeSNR(signal.red);
    if (snr < kMinSNR) {
        result.issue = QualityIssue::LowSNR;
        result.score = snr / kMinSNR;
        return result;
    }

    // All checks passed
    result.passed = true;
    result.score  = std::min(snr / (kMinSNR * 2.0f), 1.0f);
    result.issue  = QualityIssue::None;
    return result;
}

bool QualityFilter::hasMotion(const PPGFrame& current,
                               const PPGFrame& previous) {
    float motionScore = computeMotionScore(current, previous);
    return motionScore > kMaxMotionDelta;
}

float QualityFilter::computeSNR(const std::vector<float>& signal) {
    if (signal.size() < 2) return 0.0f;

    // Signal power — variance of signal
    float mean = std::accumulate(signal.begin(),
                                 signal.end(), 0.0f) / signal.size();

    float signalPower = 0.0f;
    for (float v : signal) {
        signalPower += (v - mean) * (v - mean);
    }
    signalPower /= signal.size();

    // Noise power — variance of first differences
    float noisePower = 0.0f;
    for (size_t i = 1; i < signal.size(); i++) {
        float diff = signal[i] - signal[i - 1];
        noisePower += diff * diff;
    }
    noisePower /= (signal.size() - 1);

    if (noisePower < 1e-6f) return 10.0f; // very clean signal

    return signalPower / noisePower;
}

float QualityFilter::computeMotionScore(const PPGFrame& current,
                                         const PPGFrame& previous) {
    // Motion shows as sudden large jump across all channels
    float deltaR = std::abs(current.redMean   - previous.redMean);
    float deltaG = std::abs(current.greenMean - previous.greenMean);
    float deltaB = std::abs(current.blueMean  - previous.blueMean);

    // Average delta across channels
    return (deltaR + deltaG + deltaB) / 3.0f;
}

} // namespace PulseCore
