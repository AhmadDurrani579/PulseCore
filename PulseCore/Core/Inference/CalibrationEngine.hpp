//
//  CalibrationEngine.hpp
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

#pragma once

#include <vector>
#include <deque>

namespace PulseCore {

struct CalibrationSample {
    // Finger scan ground truth
    float fingerHeartRate;
    float fingerRMSSD;
    float fingerSDNN;

    // Face scan reading at same time
    float faceHeartRate;
    float faceRMSSD;

    double timestamp;
};

struct CalibrationProfile {
    // Correction factors learned from finger vs face comparison
    float heartRateCorrectionFactor;  // multiply face HR by this
    float rmssdCorrectionFactor;      // multiply face RMSSD by this

    // Personal skin tone factors
    float redChannelWeight;
    float greenChannelWeight;
    float blueChannelWeight;

    // How many samples trained on
    size_t sampleCount;
    bool isCalibrated;  // true after minimum samples reached
};

class CalibrationEngine {
public:
    CalibrationEngine();
    ~CalibrationEngine();

    // Add a paired finger + face reading
    void addSample(const CalibrationSample& sample);

    // Apply calibration to raw face scan heart rate
    float calibrateHeartRate(float rawFaceHeartRate) const;

    // Apply calibration to raw face RMSSD
    float calibrateRMSSD(float rawFaceRMSSD) const;

    // Get current calibration profile
    CalibrationProfile getProfile() const;

    // How calibrated are we 0.0 - 1.0
    float calibrationConfidence() const;

    // Reset all learned data
    void reset();

private:
    std::deque<CalibrationSample> _samples;
    CalibrationProfile _profile;

    void recomputeProfile();

    static constexpr size_t kMinSamples     = 3;
    static constexpr size_t kMaxSamples     = 30;
    static constexpr size_t kFullCalibration = 10;
};

} // namespace PulseCore
