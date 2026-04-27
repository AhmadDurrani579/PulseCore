//
//  PPGProcessor.cpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#include "PPGProcessor.hpp"
#include <numeric>
#include <cmath>

namespace PulseCore {
PPGProcessor::PPGProcessor()
: _bufferSize(1800),
  _warmupFrames(0),
  _scanStartTime(0.0) {

}

PPGProcessor::~PPGProcessor() {}

PPGFrame PPGProcessor::processFrame(const cv::Mat& frame,
                                     double timestamp) {
    PPGFrame result;
    result.timestamp = timestamp;
    result.isValid   = false;

    if (frame.empty()) return result;

    // Skip first 10 frames for stabilisation
    // but still track time from frame 1
    _warmupFrames++;
    if (_warmupFrames < 10) {
        // Store timestamp even during warmup
        // so duration tracking starts immediately
        if (!_buffer.empty()) return result;
        result.redMean   = 0;
        result.greenMean = 0;
        result.blueMean  = 0;
        result.isValid   = false;
        return result;
    }

    cv::Vec3f means = extractROIMeans(frame);
    result.redMean   = means[2];
    result.greenMean = means[1];
    result.blueMean  = means[0];
    result.isValid   = true;

    _buffer.push_back(result);
    if (_buffer.size() > _bufferSize) {
        _buffer.pop_front();
    }

    return result;
}

void PPGProcessor::setScanStartTime(double startTime) {
    _scanStartTime = startTime;
}

double PPGProcessor::scanDuration() const {
    if (_buffer.empty()) return 0.0;
    if (_scanStartTime <= 0) return 0.0;
    return _buffer.back().timestamp - _scanStartTime;
}


cv::Vec3f PPGProcessor::extractROIMeans(const cv::Mat& frame) {
    // Use centre 60% of frame as fingertip ROI
    int roiX = frame.cols * 0.2;
    int roiY = frame.rows * 0.2;
    int roiW = frame.cols * 0.6;
    int roiH = frame.rows * 0.6;

    cv::Rect roi(roiX, roiY, roiW, roiH);
    cv::Mat roiMat = frame(roi);

    // Compute per-channel mean
    cv::Scalar means = cv::mean(roiMat);
    return cv::Vec3f(means[0], means[1], means[2]);
}

PPGSignal PPGProcessor::getSignal() const {
    PPGSignal signal;

    for (const auto& frame : _buffer) {
        if (frame.isValid) {
            signal.red.push_back(frame.redMean);
            signal.green.push_back(frame.greenMean);
            signal.blue.push_back(frame.blueMean);
            signal.timestamps.push_back(frame.timestamp);
        }
    }

    return signal;
}

float PPGProcessor::signalQuality() const {
    return computeQuality();
}

float PPGProcessor::computeQuality() const {
    if (_buffer.size() < 30) return 0.0f;

    // Compute variance of red channel
    // Higher variance = stronger PPG signal = better quality
    std::vector<float> redValues;
    for (const auto& frame : _buffer) {
        if (frame.isValid) {
            redValues.push_back(frame.redMean);
        }
    }

    if (redValues.empty()) return 0.0f;

    float mean = std::accumulate(redValues.begin(),
                                 redValues.end(), 0.0f) / redValues.size();

    float variance = 0.0f;
    for (float v : redValues) {
        variance += (v - mean) * (v - mean);
    }
    variance /= redValues.size();

    // Normalise to 0.0 - 1.0
    // Good finger PPG variance is typically 10-500
    float quality = std::min(variance / 100.0f, 1.0f);
    return quality;
}

void PPGProcessor::reset() {
    _buffer.clear();
    _warmupFrames  = 0;
    _scanStartTime = 0.0;

}

void PPGProcessor::setBufferSize(size_t size) {
    _bufferSize = size;
}



 }// namespace PulseCore
