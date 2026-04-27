//
//  AFibDetector.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "AFibDetector.hpp"
#include <cmath>
#include <numeric>
#include <algorithm>
#include <map>

namespace PulseCore {

AFibDetector::AFibDetector() {}
AFibDetector::~AFibDetector() {}

AFibResult AFibDetector::analyse(const std::vector<float>& rrIntervals) {

    AFibResult result;
    result.isValid          = false;
    result.entropyScore     = 0.0f;
    result.irregularityScore = 0.0f;
    result.confidence       = 0.0f;
    result.status           = RhythmStatus::Inconclusive;
    
    if (rrIntervals.size() < kMinIntervals) {
        return result;
    }

    // Check minimum intervals
    if (rrIntervals.size() < kMinIntervals) {
        result.status = RhythmStatus::Inconclusive;
        return result;
    }

    // Compute all three scores
    float entropy      = computeEntropy(rrIntervals);
    float irregularity = computeIrregularity(rrIntervals);
    float cv           = computeCV(rrIntervals);
    
    result.entropyScore      = entropy;
    result.irregularityScore = irregularity;
    result.isValid           = true;

    // Voting — each metric casts a vote
    int irregularVotes = 0;

    // CV is primary — most reliable metric
    if (cv > kCVThresh) irregularVotes += 2; // double weight

    // Irregularity as secondary
    if (irregularity > kIrregThresh) irregularVotes++;

    // Entropy as tertiary — least reliable for quantised signal
    // Only count if significantly high
    if (entropy > 0.90f) irregularVotes++;

    // Determine status
    if (irregularVotes >= 3) {
        result.status = RhythmStatus::Irregular;
    } else if (irregularVotes >= 2) {
        result.status = RhythmStatus::Inconclusive;
    } else {
        result.status = RhythmStatus::Normal;
    }

    // Confidence — how strongly the votes agree
    result.confidence = static_cast<float>(irregularVotes) / 3.0f;
    if (result.status == RhythmStatus::Normal) {
        result.confidence = 1.0f - result.confidence;
    }

    return result;
}

// ── Shannon Entropy ───────────────────────────────────────────────────────

float AFibDetector::computeEntropy(const std::vector<float>& rrIntervals) {
    if (rrIntervals.empty()) return 0.0f;

    // Bin RR intervals into histogram
    // Each bin = 50ms wide
    const float binWidth = 50.0f;
    std::map<int, int> histogram;

    for (float rr : rrIntervals) {
        int bin = static_cast<int>(rr / binWidth);
        histogram[bin]++;
    }

    // Compute Shannon entropy
    float entropy = 0.0f;
    float total   = static_cast<float>(rrIntervals.size());

    for (const auto& pair : histogram) {
        float p = static_cast<float>(pair.second) / total;
        if (p > 0.0f) {
            entropy -= p * std::log2(p);
        }
    }

    // Normalise by maximum possible entropy
    // Max entropy = log2(number of bins)
    float maxEntropy = std::log2(static_cast<float>(histogram.size()));
    if (maxEntropy > 0.0f) {
        entropy /= maxEntropy;
    }

    return entropy;
}

// ── RMSSD-based irregularity ──────────────────────────────────────────────

float AFibDetector::computeIrregularity(
    const std::vector<float>& rrIntervals) {

    if (rrIntervals.size() < 2) return 0.0f;

    // Compute RMSSD
    float sumSqDiff = 0.0f;
    for (size_t i = 1; i < rrIntervals.size(); i++) {
        float diff = rrIntervals[i] - rrIntervals[i - 1];
        sumSqDiff += diff * diff;
    }
    float rmssd = std::sqrt(sumSqDiff / (rrIntervals.size() - 1));

    // Normalise by mean RR interval
    float meanRR = std::accumulate(rrIntervals.begin(),
                                    rrIntervals.end(), 0.0f)
                   / rrIntervals.size();

    if (meanRR < 1e-6f) return 0.0f;

    return rmssd / meanRR;
}

// ── Coefficient of Variation ──────────────────────────────────────────────

float AFibDetector::computeCV(const std::vector<float>& rrIntervals) {
    if (rrIntervals.empty()) return 0.0f;

    // Mean
    float mean = std::accumulate(rrIntervals.begin(),
                                  rrIntervals.end(), 0.0f)
                 / rrIntervals.size();

    if (mean < 1e-6f) return 0.0f;

    // Standard deviation
    float sumSq = 0.0f;
    for (float rr : rrIntervals) {
        sumSq += (rr - mean) * (rr - mean);
    }
    float stdDev = std::sqrt(sumSq / rrIntervals.size());

    // CV = std / mean
    return stdDev / mean;
}

} // namespace PulseCore
