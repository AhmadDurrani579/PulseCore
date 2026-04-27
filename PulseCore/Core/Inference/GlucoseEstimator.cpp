//
//  GlucoseEstimator.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "GlucoseEstimator.hpp"
#include <cmath>
#include <numeric>
#include <algorithm>

namespace PulseCore {

GlucoseEstimator::GlucoseEstimator() {}
GlucoseEstimator::~GlucoseEstimator() {}

GlucoseResult GlucoseEstimator::estimate(const std::vector<float>& signal,
                                          float sampleRate) {
    GlucoseResult result;
    result.isValid              = false;
    result.trend                = GlucoseTrend::Inconclusive;
    result.confidence           = 0.0f;
    result.riseTime             = 0.0f;
    result.peakWidth            = 0.0f;
    result.augmentationIndex    = 0.0f;

    if (signal.size() < 64) return result;

    // Find peaks
    float minDistance = sampleRate * 0.5f;
    std::vector<size_t> peaks = findPeaks(signal, minDistance);

    if (peaks.size() < kMinPeaks) return result;

    // Extract and analyse each pulse wave
    std::vector<float> riseTimes;
    std::vector<float> peakWidths;
    std::vector<float> augIndices;

    for (size_t i = 1; i + 1 < peaks.size(); i++) {
        std::vector<float> pulse = extractPulse(signal,
                                                 peaks[i],
                                                 sampleRate);
        if (pulse.size() < 10) continue;

        float rt  = computeRiseTime(pulse, sampleRate);
        float pw  = computePeakWidth(pulse, sampleRate);
        float aug = computeAugmentationIndex(pulse);

        if (rt > 0)  riseTimes.push_back(rt);
        if (pw > 0)  peakWidths.push_back(pw);
        if (aug != 0) augIndices.push_back(aug);
    }

    if (riseTimes.empty()) return result;

    // Average across all pulses
    float meanRiseTime = std::accumulate(riseTimes.begin(),
                                          riseTimes.end(), 0.0f)
                         / riseTimes.size();

    float meanAugIndex = augIndices.empty() ? 0.0f :
                         std::accumulate(augIndices.begin(),
                                          augIndices.end(), 0.0f)
                         / augIndices.size();

    result.riseTime          = meanRiseTime;
    result.augmentationIndex = meanAugIndex;
    result.isValid           = true;

    // Determine glucose trend from waveform morphology
    // High glucose → higher blood viscosity
    //             → slower rise time
    //             → higher augmentation index
    if (meanRiseTime > kHighRiseTime || meanAugIndex > 0.3f) {
        result.trend      = GlucoseTrend::Rising;
        result.confidence = std::min(
            (meanRiseTime - kHighRiseTime) / 40.0f + 0.5f, 1.0f);

    } else if (meanRiseTime < kLowRiseTime && meanAugIndex < 0.1f) {
        result.trend      = GlucoseTrend::Falling;
        result.confidence = std::min(
            (kLowRiseTime - meanRiseTime) / 40.0f + 0.5f, 1.0f);

    } else {
        result.trend      = GlucoseTrend::Stable;
        result.confidence = 0.6f;
    }

    return result;
}

// ── Rise time ─────────────────────────────────────────────────────────────

float GlucoseEstimator::computeRiseTime(const std::vector<float>& pulse,
                                         float sampleRate) {
    if (pulse.empty()) return 0.0f;

    float maxVal = *std::max_element(pulse.begin(), pulse.end());
    float minVal = *std::min_element(pulse.begin(), pulse.end());
    float range  = maxVal - minVal;

    if (range < 1e-6f) return 0.0f;

    // Find 10% and 90% crossing points
    float threshold10 = minVal + range * 0.10f;
    float threshold90 = minVal + range * 0.90f;

    size_t idx10 = 0, idx90 = 0;
    bool found10 = false, found90 = false;

    for (size_t i = 0; i < pulse.size(); i++) {
        if (!found10 && pulse[i] >= threshold10) {
            idx10 = i;
            found10 = true;
        }
        if (!found90 && pulse[i] >= threshold90) {
            idx90 = i;
            found90 = true;
            break;
        }
    }

    if (!found10 || !found90 || idx90 <= idx10) return 0.0f;

    // Convert samples to milliseconds
    float riseTimeSamples = static_cast<float>(idx90 - idx10);
    return (riseTimeSamples / sampleRate) * 1000.0f;
}

// ── Peak width ────────────────────────────────────────────────────────────

float GlucoseEstimator::computePeakWidth(const std::vector<float>& pulse,
                                          float sampleRate) {
    if (pulse.empty()) return 0.0f;

    float maxVal = *std::max_element(pulse.begin(), pulse.end());
    float threshold = maxVal * 0.5f; // width at 50% of peak

    size_t leftIdx = 0, rightIdx = pulse.size() - 1;
    bool foundLeft = false;

    // Find left crossing
    for (size_t i = 0; i < pulse.size(); i++) {
        if (pulse[i] >= threshold) {
            leftIdx = i;
            foundLeft = true;
            break;
        }
    }

    if (!foundLeft) return 0.0f;

    // Find right crossing
    for (size_t i = pulse.size() - 1; i > leftIdx; i--) {
        if (pulse[i] >= threshold) {
            rightIdx = i;
            break;
        }
    }

    float widthSamples = static_cast<float>(rightIdx - leftIdx);
    return (widthSamples / sampleRate) * 1000.0f;
}

// ── Augmentation Index ────────────────────────────────────────────────────

float GlucoseEstimator::computeAugmentationIndex(
    const std::vector<float>& pulse) {

    if (pulse.size() < 10) return 0.0f;

    // Find first peak (systolic)
    float systolicPeak = 0.0f;
    size_t systolicIdx = 0;
    for (size_t i = 1; i + 1 < pulse.size() / 2; i++) {
        if (pulse[i] > pulse[i-1] && pulse[i] > pulse[i+1]) {
            if (pulse[i] > systolicPeak) {
                systolicPeak = pulse[i];
                systolicIdx  = i;
            }
        }
    }

    if (systolicIdx == 0) return 0.0f;

    // Find dicrotic notch (dip after systolic peak)
    float notchVal = systolicPeak;
    size_t notchIdx = systolicIdx;
    for (size_t i = systolicIdx; i < pulse.size() * 2 / 3; i++) {
        if (pulse[i] < notchVal) {
            notchVal = pulse[i];
            notchIdx = i;
        }
    }

    // Find diastolic peak (second peak after notch)
    float diastolicPeak = 0.0f;
    for (size_t i = notchIdx; i + 1 < pulse.size(); i++) {
        if (pulse[i] > pulse[i-1] && pulse[i] > pulse[i+1]) {
            if (pulse[i] > diastolicPeak) {
                diastolicPeak = pulse[i];
            }
        }
    }

    if (systolicPeak < 1e-6f) return 0.0f;

    // Augmentation index = diastolic / systolic
    return diastolicPeak / systolicPeak;
}

// ── Extract single pulse ──────────────────────────────────────────────────

std::vector<float> GlucoseEstimator::extractPulse(
    const std::vector<float>& signal,
    size_t peakIndex,
    float sampleRate) {

    // Extract half beat before and after peak
    size_t halfWindow = static_cast<size_t>(sampleRate * 0.4f);

    size_t start = peakIndex > halfWindow ? peakIndex - halfWindow : 0;
    size_t end   = std::min(peakIndex + halfWindow, signal.size() - 1);

    return std::vector<float>(signal.begin() + start,
                               signal.begin() + end);
}

// ── Find peaks ────────────────────────────────────────────────────────────

std::vector<size_t> GlucoseEstimator::findPeaks(
    const std::vector<float>& signal,
    float minDistance) {

    std::vector<size_t> peaks;
    size_t minDist = static_cast<size_t>(minDistance);

    float maxVal    = *std::max_element(signal.begin(), signal.end());
    float minHeight = maxVal * 0.3f;

    for (size_t i = 1; i + 1 < signal.size(); i++) {
        if (signal[i] > signal[i-1] &&
            signal[i] > signal[i+1] &&
            signal[i] >= minHeight) {

            if (peaks.empty() || (i - peaks.back()) >= minDist) {
                peaks.push_back(i);
            } else if (signal[i] > signal[peaks.back()]) {
                peaks.back() = i;
            }
        }
    }

    return peaks;
}

} // namespace PulseCore
