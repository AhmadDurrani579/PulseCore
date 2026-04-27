//
//  PulseCoreSession.swift
//  PulseCore
//
//  Created by Ahmad on 17/04/2026.
//

import Foundation
import AVFoundation


// MARK: - Public result types

public struct PulseScanResult: Equatable {
    // Heart
    public let heartRate: Float
    public let heartRateConfidence: Float

    // HRV
    public let rmssd: Float
    public let sdnn: Float

    // Breathing
    public let breathingRate: Float

    // AFib
    public let rhythmStatus: RhythmStatus
    public let rhythmMessage: String

    // Glucose
    public let glucoseTrend: GlucoseTrend
    public let glucoseMessage: String

    // Recovery
    public let recoveryScore: Float
    public let recoveryLevel: RecoveryLevel
    public let recoveryMessage: String

    // Wellness
    public let wellnessScore: Float
    public let wellnessMessage: String
    
    public let isFromFaceScan: Bool

}

public enum RhythmStatus: Equatable {
    case normal
    case irregular
    case inconclusive
}

public enum GlucoseTrend: Equatable {
    case rising
    case falling
    case stable
    case inconclusive
}

public enum RecoveryLevel: Equatable {
    case peak
    case good
    case moderate
    case low
    case depleted
}

public enum ScanQuality {
    case good
    case weak
    case motion
    case notEnoughData
    case lowSNR
}

public struct ScanQualityUpdate {
    public let passed: Bool
    public let score: Float
    public let quality: ScanQuality
    public let message: String
}

// MARK: - Delegate

public protocol PulseCoreSessionDelegate: AnyObject {
    func session(_ session: PulseCoreSession,
                 didUpdateQuality quality: ScanQualityUpdate)
    func session(_ session: PulseCoreSession,
                 didUpdateProgress progress: Float)
    func session(_ session: PulseCoreSession,
                 didCompleteWithResult result: PulseScanResult)
    func session(_ session: PulseCoreSession,
                 didFailWithError error: String)
}

// MARK: - Session

public class PulseCoreSession: NSObject {

    public weak var delegate: PulseCoreSessionDelegate?

    private let processor = PulseCoreProcessor()
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isRunning = false
    private var scanMode: PulseCoreScanMode = .finger
    
    private let sessionQueue = DispatchQueue(label: "com.pulsecore.session")
    private let outputQueue  = DispatchQueue(label: "com.pulsecore.output")

    // MARK: - Public API

    public func startFingerScan() {
        scanMode = .finger
        processor.reset()
        startCapture(position: .back)
    }
    
    public func startFaceScan() {
        scanMode = .face
        processor.reset()

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Fully stop and wait
            self.captureSession.stopRunning()
            self.enableTorch(on: false)

            // Wait for hardware to release
            Thread.sleep(forTimeInterval: 1.0)

            // Now start front camera
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            guard status == .authorized else {
                AVCaptureDevice.requestAccess(for: .video) { _ in }
                return
            }

            self.startCapture(position: .front)
        }
    }

    public func stopScan() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.enableTorch(on: false)
            self.captureSession.stopRunning()
            self.isRunning = false
        }

    }
    
    public func currentRMSSD() -> Float {
        return processor.currentRMSSD()
    }

    public func currentBreathingRate() -> Float {
        return processor.currentBreathingRate()
    }


    public func reset() {
        processor.reset()
    }

    public func getResult() -> PulseScanResult? {
        let raw = processor.currentResult()
        guard raw.isValid else { return nil }
        return mapResult(raw)
    }
    
    public func recentSamples() -> [Float] {
        if scanMode == .face {
            return processor.recentFaceSamples().map { $0.floatValue }
        }
        return processor.recentSamples().map { $0.floatValue }
    }

    public func currentHeartRate() -> Float {
        return processor.currentHeartRate()
    }
    
    public func currentFaceHeartRate() -> Float {
        return processor.currentHeartRate()
    }


    public func forceResult() -> PulseScanResult {
        let raw = processor.currentResult()

        // Return real data if available
        if raw.heartRateBPM > 0 {
            return mapResult(raw)
        }

        // Return placeholder result so UI always shows
        return PulseScanResult(
            heartRate:           72,
            heartRateConfidence: 0.5,
            rmssd:               35,
            sdnn:                45,
            breathingRate:       20,
            rhythmStatus:        .inconclusive,
            rhythmMessage:       "Not enough data for rhythm analysis",
            glucoseTrend:        .inconclusive,
            glucoseMessage:      "Not enough data for glucose estimate",
            recoveryScore:       50,
            recoveryLevel:       .moderate,
            recoveryMessage:     "Scan again for accurate reading",
            wellnessScore:       50,
            wellnessMessage:     "Complete a full scan for results",
            isFromFaceScan:      false
        )
    }


    
    // MARK: - Camera setup

    private func startCapture(position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop if running
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Thread.sleep(forTimeInterval: 0.3)
            }

            self.captureSession.beginConfiguration()

            // Set preset based on camera
            if position == .front {
                self.captureSession.sessionPreset = .vga640x480
            } else {
                self.captureSession.sessionPreset = .medium
            }

            // Remove existing inputs
            self.captureSession.inputs.forEach {
                self.captureSession.removeInput($0)
            }

            // Remove existing outputs
            self.captureSession.outputs.forEach {
                self.captureSession.removeOutput($0)
            }

            // Get camera device
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            ) else {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.delegate?.session(self,
                        didFailWithError: "Camera not available")
                }
                return
            }

            // Add camera input
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                } else {
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async {
                        self.delegate?.session(self,
                            didFailWithError: "Cannot add camera input")
                    }
                    return
                }
            } catch {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.delegate?.session(self,
                        didFailWithError: error.localizedDescription)
                }
                return
            }

            // Add video output
            self.videoOutput.setSampleBufferDelegate(
                self,
                queue: self.outputQueue
            )
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA
            ]

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            self.isRunning = true

            // Turn torch on AFTER session starts — back camera only
            if position == .back {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.enableTorch(on: true)
                }
            }
        }
    }
    
    private func enableTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { return }

        guard device.hasTorch && device.isTorchAvailable else { return }

        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension PulseCoreSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Process frame
        let quality = processor.processSampleBuffer(sampleBuffer,
                                                     mode: scanMode)

        // Map quality result
        let qualityUpdate = ScanQualityUpdate(
            passed:  quality.passed,
            score:   quality.score,
            quality: mapQualityIssue(quality.issue),
            message: quality.message
        )

        let progress = processor.scanProgress()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.session(self, didUpdateQuality: qualityUpdate)
            self.delegate?.session(self, didUpdateProgress: progress)
        }

        // Check if scan is complete
        if processor.isReadyForResult() {
            let result = processor.currentResult()

            if result.isValid {
                let scanResult = mapResult(result)

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.session(self,
                        didCompleteWithResult: scanResult)
                    self.stopScan()
                }
            }
        }
    }

    public func currentProgress() -> Float {
        return processor.scanProgress()
    }

    // MARK: - Mapping helpers

    private func mapQualityIssue(
        _ issue: PulseCoreQualityIssue) -> ScanQuality {
        switch issue {
        case .none:           return .good
        case .signalTooWeak:  return .weak
        case .motionDetected: return .motion
        case .notEnoughData:  return .notEnoughData
        case .lowSNR:         return .lowSNR
        @unknown default:     return .notEnoughData
        }
    }

    private func mapResult(_ result: PulseCoreResult) -> PulseScanResult {
        return PulseScanResult(
            heartRate:           result.heartRateBPM > 0 ? result.heartRateBPM : 0,
            heartRateConfidence: result.heartRateConfidence,
            rmssd:               result.rmssd,
            sdnn:                result.sdnn,
            breathingRate:       result.breathingRate,
            rhythmStatus:        mapRhythm(result.rhythmStatus),
            rhythmMessage:       result.rhythmMessage,
            glucoseTrend:        mapGlucose(result.glucoseTrend),
            glucoseMessage:      result.glucoseMessage,
            recoveryScore:       result.recoveryScore,
            recoveryLevel:       mapRecovery(result.recoveryLevel),
            recoveryMessage:     result.recoveryMessage,
            wellnessScore:       result.wellnessScore,
            wellnessMessage:     result.wellnessMessage,
            isFromFaceScan:      result.isFromFaceScan
        )
    }

    private func mapRhythm(
        _ status: PulseCoreRhythmStatus) -> RhythmStatus {
        switch status {
        case .normal:        return .normal
        case .irregular:     return .irregular
        case .inconclusive:  return .inconclusive
        @unknown default:    return .inconclusive
        }
    }

    private func mapGlucose(
        _ trend: PulseCoreGlucoseTrend) -> GlucoseTrend {
        switch trend {
        case .rising:        return .rising
        case .falling:       return .falling
        case .stable:        return .stable
        case .inconclusive:  return .inconclusive
        @unknown default:    return .inconclusive
        }
    }

    private func mapRecovery(
        _ level: PulseCoreRecoveryLevel) -> RecoveryLevel {
        switch level {
        case .peak:      return .peak
        case .good:      return .good
        case .moderate:  return .moderate
        case .low:       return .low
        case .depleted:  return .depleted
        @unknown default: return .moderate
        }
    }
}
