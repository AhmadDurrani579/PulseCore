//
//  DashboardView.swift
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

import SwiftUI
import PulseCore

struct DashboardView: View {

    @ObservedObject private var store = ReadingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Nav
                    HStack {
                        Button { dismiss() } label: {
                            Text("Done")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "34C759"))
                        }
                        Spacer()
                        Text("Your trends")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Done").opacity(0)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    if store.readings.isEmpty {
                        DashboardEmptyState()
                            .padding(.top, 40)
                    } else {

                        Text("Weekly averages")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            DashMetricCard(label: "Avg heart rate",
                                           value: "\(avgHeartRate.safeInt)",
                                           unit: "BPM")
                            DashMetricCard(label: "Avg HRV",
                                           value: "\(avgHRV.safeInt)",
                                           unit: "ms")
                            DashMetricCard(label: "Avg body battery",
                                           value: "\(avgRecovery.safeInt)",
                                           unit: "%")
                            DashMetricCard(label: "Avg breathing",
                                           value: "\(avgBreathing.safeInt)",
                                           unit: "/min")
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Text("Heart rate — last scans")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        DashChart(
                            values: store.readings.map { $0.heartRate },
                            color: Color(hex: "FF453A"),
                            unit: "BPM"
                        )
                        .frame(height: 110)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Text("HRV — last scans")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        DashChart(
                            values: store.readings.map { $0.rmssd },
                            color: Color(hex: "378ADD"),
                            unit: "ms"
                        )
                        .frame(height: 110)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Text("Body battery — last scans")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        DashChart(
                            values: store.readings.map { $0.recoveryScore },
                            color: Color(hex: "34C759"),
                            unit: "%"
                        )
                        .frame(height: 110)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Text("Recent readings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        ForEach(store.readings.indices, id: \.self) { i in
                            DashReadingRow(
                                reading: store.readings[i],
                                index: i + 1
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    var avgHeartRate: Float {
        guard !store.readings.isEmpty else { return 0 }
        return store.readings.map { $0.heartRate }.reduce(0, +) /
               Float(store.readings.count)
    }

    var avgHRV: Float {
        guard !store.readings.isEmpty else { return 0 }
        return store.readings.map { $0.rmssd }.reduce(0, +) /
               Float(store.readings.count)
    }

    var avgRecovery: Float {
        guard !store.readings.isEmpty else { return 0 }
        return store.readings.map { $0.recoveryScore }.reduce(0, +) /
               Float(store.readings.count)
    }

    var avgBreathing: Float {
        guard !store.readings.isEmpty else { return 0 }
        return store.readings.map { $0.breathingRate }.reduce(0, +) /
               Float(store.readings.count)
    }
}

// MARK: - Dash metric card

struct DashMetricCard: View {
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
                    .font(.system(size: 11))
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

// MARK: - Dash chart

struct DashChart: View {
    let values: [Float]
    let color: Color
    let unit: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1a1a1a"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
                )

            if values.count > 1 {
                GeometryReader { geo in
                    let w      = geo.size.width - 32
                    let h      = geo.size.height - 32
                    let minV   = values.min() ?? 0
                    let maxV   = values.max() ?? 1
                    let range  = maxV - minV
                    let step   = w / CGFloat(values.count - 1)

                    ZStack {
                        // Line
                        Path { path in
                            for (i, val) in values.enumerated() {
                                let x = CGFloat(i) * step + 16
                                let norm = range > 0 ?
                                    CGFloat((val - minV) / range) : 0.5
                                let y = h - (norm * h) + 16
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(color, lineWidth: 2)

                        // Dots
                        ForEach(values.indices, id: \.self) { i in
                            let val  = values[i]
                            let x    = CGFloat(i) * step + 16
                            let norm = range > 0 ?
                                CGFloat((val - minV) / range) : 0.5
                            let y    = h - (norm * h) + 16

                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                                .position(x: x, y: y)
                        }

                        // Min max labels
                        VStack {
                            Text("\(maxV.safeInt) \(unit)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "48484a"))
                                .frame(maxWidth: .infinity,
                                       alignment: .trailing)
                                .padding(.trailing, 10)
                            Spacer()
                            Text("\(minV.safeInt) \(unit)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "48484a"))
                                .frame(maxWidth: .infinity,
                                       alignment: .trailing)
                                .padding(.trailing, 10)
                        }
                        .padding(.vertical, 10)
                    }
                }
            } else {
                Text("Not enough data yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "48484a"))
            }
        }
    }
}

// MARK: - Reading row

struct DashReadingRow: View {
    let reading: SavedReading
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "0d2b1a"))
                    .frame(width: 38, height: 38)
                Text("\(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "34C759"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(reading.formattedDate)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(Int(reading.heartRate)) BPM · HRV \(Int(reading.rmssd))ms · Battery \(Int(reading.recoveryScore))%")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "48484a"))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(reading.isFromFaceScan ?
                          Color(hex: "1a1730") :
                          Color(hex: "0d2b1a"))
                    .frame(width: 28, height: 28)
                Image(systemName: reading.isFromFaceScan ?
                      "face.smiling" : "hand.point.up.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(reading.isFromFaceScan ?
                                     Color(hex: "5E5CE6") :
                                     Color(hex: "34C759"))
            }
        }
        .padding(14)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

// MARK: - Empty state

struct DashboardEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1a1a1a"))
                    .frame(width: 64, height: 64)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(hex: "48484a"))
            }

            Text("No readings yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("Complete your first scan to start tracking your health trends over time.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "48484a"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
        }
    }
}
