//
//  HomeView.swift
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//


import SwiftUI
import PulseCore

struct HomeView: View {

    @State private var navigateToFinger = false
    @State private var navigateToFace   = false
    @State private var scanResult: PulseScanResult? = nil
    @State private var showResults = false
    @StateObject private var store = ReadingsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f0f").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good morning")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "48484a"))
                            Text("PulseCore")
                                .font(.system(size: 28,
                                              weight: .bold,
                                              design: .default))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        // Battery card
                        if let last = store.lastReading {
                            BatteryCardFromStore(reading: last)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        } else {
                            EmptyBatteryCard()
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        // Section label
                        Text("Start a scan")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // Finger scan button
                        ScanRowButton(
                            title: "Finger scan",
                            subtitle: "Full reading · 30 seconds",
                            color: Color(hex: "34C759"),
                            iconBg: Color(hex: "0d2b1a"),
                            icon: "hand.point.up.fill"
                        ) {
                            navigateToFinger = true
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                        // Face scan button
                        ScanRowButton(
                            title: "Face scan",
                            subtitle: "Quick check · 15 seconds",
                            color: Color(hex: "5E5CE6"),
                            iconBg: Color(hex: "1a1730"),
                            icon: "face.smiling"
                        ) {
                            navigateToFace = true
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        // Last reading
                        Text("Last reading")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        if let last = store.lastReading {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ReadingMetricCard(
                                    label: "Heart rate",
                                    value: "\(Int(last.heartRate))",
                                    unit: "BPM")
                                ReadingMetricCard(
                                    label: "Body battery",
                                    value: "\(Int(last.recoveryScore))",
                                    unit: "%")
                                ReadingMetricCard(
                                    label: "Breathing",
                                    value: "\(Int(last.breathingRate))",
                                    unit: "/min")
                                ReadingMetricCard(
                                    label: "Stress",
                                    value: "\(Int(100 - last.recoveryScore))",
                                    unit: "/100")
                            }
                            .padding(.horizontal, 16)
                        } else {
                            EmptyLastReading()
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToFinger) {
                ScanView(mode: .finger) { result in
                    scanResult       = result
                    navigateToFinger = false
                    showResults      = true
                }
            }
            .navigationDestination(isPresented: $navigateToFace) {
                ScanView(mode: .face) { result in
                    scanResult     = result
                    navigateToFace = false
                    showResults    = true
                }
            }
            .navigationDestination(isPresented: $showResults) {
                if let result = scanResult {
                    ResultsView(result: result)
                }
            }
        }
    }
}

// MARK: - Battery card

struct BatteryCard: View {
    let result: PulseScanResult

    var safeScore: Float {
        guard result.recoveryScore.isFinite else { return 0 }
        return max(0, min(result.recoveryScore, 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Body battery")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "48484a"))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 6)

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(safeScore))")
                    .font(.system(size: 48, weight: .bold,
                                  design: .default))
                    .foregroundStyle(.white)
                    .kerning(-2)
                Text("%")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "48484a"))
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 4)

            Text(result.recoveryMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "34C759"))
                .padding(.bottom, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "2a2a2a"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "34C759"))
                        .frame(width: geo.size.width *
                               CGFloat(safeScore / 100),
                               height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

struct BatteryCardFromStore: View {
    let reading: SavedReading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Body battery")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "48484a"))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 6)

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(reading.recoveryScore))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(-2)
                Text("%")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "48484a"))
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 4)

            Text(reading.formattedDate)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "34C759"))
                .padding(.bottom, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "2a2a2a"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "34C759"))
                        .frame(
                            width: geo.size.width *
                                   CGFloat(reading.recoveryScore / 100),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

struct EmptyBatteryCard: View {
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "222222"))
                    .frame(width: 52, height: 52)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "48484a"))
            }
            Text("No readings yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Complete your first finger scan to see your body battery and health trends here.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "48484a"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

// MARK: - Scan row button

struct ScanRowButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let iconBg: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "48484a"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "3a3a3c"))
            }
            .padding(16)
            .background(Color(hex: "1a1a1a"))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Last reading grid


struct ReadingMetricCard: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "48484a"))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(-0.5)
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "48484a"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

struct EmptyLastReading: View {
    var body: some View {
        Text("No readings yet. Complete a scan to see your vitals here.")
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: "48484a"))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "1a1a1a"))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
            )
    }
}

// MARK: - Color extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}
