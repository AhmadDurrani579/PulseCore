//
//  ScanViewModel.swift
//  PulseCore
//
//  Created by Ahmad on 17/04/2026.
//

import Combine
import Foundation
import PulseCore

class ScanViewModel: NSObject, ObservableObject,
                     PulseCoreSessionDelegate {

    @Published var isScanning: Bool      = false
    @Published var progress: Float       = 0
    @Published var qualityScore: Float   = 0
    @Published var qualityMessage: String = "Ready"
    @Published var liveHeartRate: Float  = 0
    @Published var waveformSamples: [Float] = []
    @Published var result: PulseScanResult? = nil
    @Published var elapsedSeconds: Int   = 0
    @Published var fingerDetected: Bool  = false
    @Published var isPulsing: Bool       = false
    private var isFingerMode: Bool = true

    @Published var liveHRV: Float = 0
    @Published var liveBreathing: Float = 0
    private var currentMode: ScanMode = .finger
    private var hrHistory: [Float] = []

    let session = PulseCoreSession()
    private var timer: Timer?
    private var waveTimer: Timer?
    private var totalSeconds: Int = 30

    override init() {
        super.init()
        session.delegate = self
    }

    func startScan(mode: ScanMode) {
        currentMode     = mode
        isFingerMode = mode == .finger
        result          = nil
        isScanning      = true
        elapsedSeconds  = 0
        fingerDetected  = false
        progress        = 0
        liveHeartRate   = 0
        waveformSamples = []
        totalSeconds    = mode == .finger ? 30 : 15

        if mode == .finger {
            session.startFingerScan()
        } else {
            session.startFaceScan()
        }
    }

    func stopScan() {
        session.stopScan()
        pauseTimer()
        stopWaveTimer()
        isScanning  = false
        isPulsing   = false
    }

    // MARK: - Timers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let p = self.session.currentProgress()
            self.progress       = p
            self.elapsedSeconds = Int(p * Float(self.totalSeconds))

            // Update all three live metrics
            let hr = self.session.currentHeartRate()
            if hr > 30 && hr < 220 {
                self.hrHistory.append(hr)
                if self.hrHistory.count > 8 {
                    self.hrHistory.removeFirst()
                }

                // Remove outliers before averaging
                // Reject values more than 30% from current median
                let sorted = self.hrHistory.sorted()
                let median = sorted[sorted.count / 2]
                let filtered = self.hrHistory.filter {
                    abs($0 - median) / median < 0.30
                }

                if !filtered.isEmpty {
                    let avgHR = filtered.reduce(0, +) / Float(filtered.count)
                    self.liveHeartRate = avgHR
                }
            }

            let br = self.session.currentBreathingRate()
            if br > 0 {
                self.liveBreathing = br
            }
            print("Live metrics — HR: \(hr) BR: \(br) progress: \(p)")

            if self.isFingerMode {
                let hrv = self.session.currentRMSSD()
                if hrv > 0 { self.liveHRV = hrv }
            } else {
                // Face scan — show stress estimate instead of HRV
                let stressEstimate: Float = hr > 80 ?
                    min((hr - 60) * 1.5, 100) : 20
                self.liveHRV = stressEstimate
            }

            if p >= 1.0 {
                self.pauseTimer()
                self.completeScan()
            }
        }
    }


    private func startWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = Timer.scheduledTimer(
            withTimeInterval: 0.08,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let samples = self.session.recentSamples()
            if !samples.isEmpty {
                self.waveformSamples = samples
            }
        }
    }


    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = nil
    }

    private func completeScan() {
        stopWaveTimer()
        isScanning     = false
        progress       = 1.0
        elapsedSeconds = totalSeconds
        isPulsing      = false
        session.stopScan()
        self.result = session.forceResult()
    }

    // MARK: - Delegate

    func session(_ session: PulseCoreSession,
                 didUpdateQuality quality: ScanQualityUpdate) {
        print("Quality received: \(quality.quality) message: \(quality.message) score: \(quality.score)")
        qualityScore   = quality.score
        qualityMessage = quality.message
        
        // For face scan start timer as soon as any frame comes through
        // For finger scan require good signal first
        let isActive: Bool
        if currentMode == .face {
            isActive = quality.quality == .good ||
                       quality.message == "Face detected — reading signal"
        } else {
            isActive = quality.quality != .notEnoughData
        }

        if isActive && !fingerDetected {
            print("Starting timer — isActive: \(isActive) mode: \(currentMode)")
            fingerDetected = true
            isPulsing      = true
            startTimer()
            startWaveTimer()
        } else if !isActive && fingerDetected &&
                  currentMode == .finger {
            fingerDetected = false
            isPulsing      = false
            pauseTimer()
            stopWaveTimer()
        }
    }

    func session(_ session: PulseCoreSession,
                 didUpdateProgress progress: Float) {}

    func session(_ session: PulseCoreSession,
                 didCompleteWithResult result: PulseScanResult) {
        if self.result == nil {
            self.result = result
            isScanning  = false
            isPulsing   = false
            pauseTimer()
            stopWaveTimer()
        }
    }

    func session(_ session: PulseCoreSession,
                 didFailWithError error: String) {
        qualityMessage = error
        isScanning     = false
        isPulsing      = false
        pauseTimer()
        stopWaveTimer()
    }
}


