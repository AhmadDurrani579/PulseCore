//
//  PPGProcessor.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include <opencv2/opencv.hpp>
#include <vector>
#include <deque>

namespace PulseCore {

struct PPGFrame {
    double timestamp;
    float redMean;
    float greenMean;
    float blueMean;
    bool isValid;
};

struct PPGSignal {
    std::vector<float> red;
    std::vector<float> green;
    std::vector<float> blue;
    std::vector<double> timestamps;

    // 30 seconds of data based on actual timestamps
    bool hasEnoughData() const {
        return red.size() >= 256;
    }
};

class PPGProcessor {
public:
    PPGProcessor();
    ~PPGProcessor();

    // Feed one camera frame in
    PPGFrame processFrame(const cv::Mat& frame,
                          double timestamp = 0.0);

    // Get accumulated signal
    PPGSignal getSignal() const;

    // Check signal quality (0.0 - 1.0)
    float signalQuality() const;

    // Reset buffer
    void reset();

    void setBufferSize(size_t size);
    
    void setScanStartTime(double startTime);
    double scanDuration() const;


private:
    std::deque<PPGFrame> _buffer;
    size_t _bufferSize;
    int _warmupFrames;
    cv::Vec3f extractROIMeans(const cv::Mat& frame);
    float computeQuality() const;
    double _scanStartTime;

};

} // namespace PulseCore // namespace PulseCore
