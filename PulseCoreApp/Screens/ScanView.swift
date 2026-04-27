//
//  ScanView.swift
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

import SwiftUI
import PulseCore

@MainActor
enum ScanMode: Sendable {
    case finger
    case face
}

struct ScanView: View {

    let mode: ScanMode
    let onComplete: (PulseScanResult) -> Void

    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var accentColor: Color {
        mode == .finger ? Color(hex: "34C759") : Color(hex: "5E5CE6")
    }

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            VStack(spacing: 0) {

                // Nav
                HStack {
                    Button {
                        viewModel.stopScan()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                    }
                    Spacer()
                    Text(mode == .finger ? "Finger scan" : "Face scan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Cancel").opacity(0)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(hex: "1a1a1a"), lineWidth: 9)
                        .frame(width: 178, height: 178)

                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.progress))
                        .stroke(accentColor,
                                style: StrokeStyle(lineWidth: 9,
                                                   lineCap: .round))
                        .frame(width: 178, height: 178)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3),
                                   value: viewModel.progress)

                    Circle()
                        .fill(Color(hex: "0f0f0f"))
                        .frame(width: 158, height: 158)

                    // Center content
                    VStack(spacing: 4) {
                        if viewModel.liveHeartRate > 30 {
                            Text("\(Int(viewModel.liveHeartRate))")
                                .font(.system(size: 48,
                                              weight: .bold))
                                .foregroundStyle(accentColor)
                                .kerning(-2)
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.3),
                                           value: viewModel.liveHeartRate)
                            Text("BPM live")
                                .font(.system(size: 12,
                                              weight: .medium))
                                .foregroundStyle(Color(hex: "48484a"))
                        } else if mode == .finger {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    viewModel.isScanning ?
                                    accentColor :
                                    Color(hex: "48484a")
                                )
                            Text(viewModel.isScanning ?
                                 "Measuring" : "Place finger")
                                .font(.system(size: 12,
                                              weight: .medium))
                                .foregroundStyle(Color(hex: "48484a"))
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    viewModel.isScanning ?
                                    accentColor :
                                    Color(hex: "48484a")
                                )
                            Text(viewModel.isScanning ?
                                 "Reading face" : "Look at camera")
                                .font(.system(size: 12,
                                              weight: .medium))
                                .foregroundStyle(Color(hex: "48484a"))
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .scaleEffect(viewModel.isPulsing ? 1.02 : 1.0)
                .animation(
                    viewModel.fingerDetected ?
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true) :
                    .default,
                    value: viewModel.isPulsing
                )

                // Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.fingerDetected ?
                              accentColor : Color(hex: "3a3a3c"))
                        .frame(width: 6, height: 6)
                    Text(viewModel.qualityMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.fingerDetected ?
                                         accentColor :
                                         Color(hex: "48484a"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    viewModel.fingerDetected ?
                    accentColor.opacity(0.1) :
                    Color(hex: "1a1a1a")
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            viewModel.fingerDetected ?
                            accentColor.opacity(0.3) :
                            Color(hex: "2a2a2a"),
                            lineWidth: 0.5
                        )
                )
                .padding(.bottom, 12)

                // Waveform
                WaveformViewNew(
                    samples: viewModel.waveformSamples,
                    color: accentColor
                )
                .frame(height: 60)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Timer row
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                    Text(String(format: "0:%02d",
                                viewModel.elapsedSeconds))
                        .font(.system(size: 20, weight: .semibold,
                                      design: .monospaced))
                        .foregroundStyle(.white)
                    Text(mode == .finger ? "/ 0:30" : "/ 0:15")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "3a3a3c"))
                }
                .padding(.bottom, 6)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "1a1a1a"))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: geo.size.width *
                                   CGFloat(viewModel.progress))
                            .animation(.linear(duration: 0.3),
                                       value: viewModel.progress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Live metrics
                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        LiveMetricCard(
                            value: viewModel.liveHeartRate > 0 ?
                                   "\(viewModel.liveHeartRate.safeInt)" : "--",
                            label: "BPM",
                            color: accentColor
                        )
                        LiveMetricCard(
                            value: viewModel.liveHRV > 0 ?
                                   "\(viewModel.liveHRV.safeInt)" : "--",
                            label: mode == .finger ? "HRV ms" : "Stress",
                            color: accentColor
                        )
                        LiveMetricCard(
                            value: viewModel.liveBreathing > 0 ?
                                   "\(viewModel.liveBreathing.safeInt)" : "--",
                            label: "Breath",
                            color: accentColor
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }

                // Instruction
                Text(instructionText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "48484a"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(3)

                Spacer()

                // Start button
                if !viewModel.isScanning {
                    Button {
                        viewModel.startScan(mode: mode)
                    } label: {
                        Text(mode == .finger ?
                             "Start scan" : "Start face scan")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(15)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(
                                cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.result) { _, result in
            if let result = result {
                onComplete(result)
            }
        }
    }

    var instructionText: String {
        if !viewModel.isScanning {
            return mode == .finger ?
                "Place the pad of your index finger firmly over the camera and torch" :
                "Hold phone at arm's length. Front camera reads colour changes in your skin."
        }
        return viewModel.qualityMessage
    }
}

// MARK: - Waveform

struct WaveformViewNew: View {
    let samples: [Float]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "141414"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "2a2a2a"),
                                    lineWidth: 0.5)
                    )

                if samples.count > 2 {
                    Path { path in
                        let w    = geo.size.width - 24
                        let h    = geo.size.height - 16
                        let step = w / CGFloat(samples.count - 1)
                        let minV = samples.min() ?? 0
                        let maxV = samples.max() ?? 1
                        let range = maxV - minV

                        for (i, s) in samples.enumerated() {
                            let x = CGFloat(i) * step + 12
                            let norm = range > 0 ?
                                CGFloat((s - minV) / range) : 0.5
                            let y = h - (norm * h * 0.8 +
                                         h * 0.1) + 8
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2)
                } else {
                    Text("Live signal")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "2a2a2a"))
                }

                // Label bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(samples.count > 2 ?
                             "Live PPG signal" :
                             "Waiting for signal")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "2a2a2a"))
                            .padding(.trailing, 10)
                            .padding(.bottom, 5)
                    }
                }
            }
        }
    }
}

// MARK: - Live metric card

struct LiveMetricCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "48484a"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

