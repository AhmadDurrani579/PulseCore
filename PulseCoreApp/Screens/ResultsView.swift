//
//  ResultsView.swift
//  PulseCore
//
//  Created by Ahmad on 16/04/2026.
//

import SwiftUI
import PulseCore

struct ResultsView: View {

    let result: PulseScanResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Nav
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "34C759"))
                        }
                        Spacer()
                        Text("Your results")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Done").opacity(0)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // Hero card
                    HeroCard(result: result)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // Body battery
                    SectionLabel(title: "Body battery")
                    BodyBatteryResultCard(result: result)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // Vitals grid
                    SectionLabel(title: "Vitals")
                    if !result.isFromFaceScan {
                        VitalsGrid(result: result)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    } else {
                        FaceVitalsGrid(result: result)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    // Glucose
                    if !result.isFromFaceScan {
                        SectionLabel(title: "Glucose trend")
                        GlucoseResultCard(result: result)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }


                    // Message
                    MessageCard(result: result)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // Actions
                    HStack(spacing: 10) {
                        Button {
                            ReadingsStore.shared.save(result)

                            dismiss()
                        } label: {
                            Text("Save reading")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(15)
                                .background(Color(hex: "34C759"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "636366"))
                                .padding(15)
                                .background(Color(hex: "1a1a1a"))
                                .clipShape(RoundedRectangle(
                                    cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "2a2a2a"),
                                                lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Hero card

struct HeroCard: View {
    let result: PulseScanResult

    var safeHR: Float {
        guard result.heartRate.isFinite else { return 0 }
        return max(0, min(result.heartRate, 300))
    }

    var safeRecovery: Float {
        guard result.recoveryScore.isFinite else { return 0 }
        return max(0, min(result.recoveryScore, 100))
    }

    var body: some View {
        VStack(spacing: 12) {

            // Arc + BPM
            ZStack {
                Circle()
                    .stroke(Color(hex: "1f1f1f"), lineWidth: 9)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(safeRecovery / 100))
                    .stroke(
                        arcColor,
                        style: StrokeStyle(lineWidth: 9,
                                           lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color(hex: "1a1a1a"))
                    .frame(width: 130, height: 150)

                VStack(spacing: 2) {
                    Text("\(safeHR.safeInt)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(arcColor)
                        .kerning(-2)
                    Text("BPM · Heart rate")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "48484a"))
                }
            }

            // Rhythm pill — finger scan only
            // Face scan shows scan type label instead
            if result.isFromFaceScan {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "5E5CE6"))
                        .frame(width: 6, height: 6)
                    Text("Face scan · quick check")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "5E5CE6"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: "5E5CE6").opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "5E5CE6").opacity(0.3),
                                lineWidth: 0.5)
                )
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(rhythmColor)
                        .frame(width: 6, height: 6)
                    Text(result.rhythmMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(rhythmColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(rhythmColor.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(rhythmColor.opacity(0.3),
                                lineWidth: 0.5)
                )
            }

            // Timestamp
            Text(timestamp)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "3a3a3c"))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }

    var arcColor: Color {
        result.isFromFaceScan ?
            Color(hex: "5E5CE6") :
            Color(hex: "34C759")
    }

    var rhythmColor: Color {
        switch result.rhythmStatus {
        case .normal:       return Color(hex: "34C759")
        case .irregular:    return Color(hex: "FF453A")
        case .inconclusive: return Color(hex: "FF9F0A")
        }
    }

    var timestamp: String {
        let now = Date()
        let f   = DateFormatter()
        f.dateFormat = "EEEE · HH:mm"
        return f.string(from: now)
    }
}

// MARK: - Body battery result card

struct BodyBatteryResultCard: View {
    let result: PulseScanResult

    var safeScore: Float {
        guard result.recoveryScore.isFinite else { return 0 }
        return max(0, min(result.recoveryScore, 100))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery score")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "48484a"))
                    HStack(alignment: .firstTextBaseline,
                           spacing: 2) {
                        Text("\(safeScore.safeInt)")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                            .kerning(-1)
                        Text("%")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "48484a"))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.recoveryLevel.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(batteryColor)
                    Text("Ready for activity")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "48484a"))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "2a2a2a"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(batteryColor)
                        .frame(
                            width: geo.size.width *
                                   CGFloat(safeScore / 100),
                            height: 6
                        )
                        .animation(.easeOut(duration: 0.8),
                                   value: safeScore)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }

    var batteryColor: Color {
        switch result.recoveryScore {
        case 80...100: return Color(hex: "34C759")
        case 60...80:  return Color(hex: "30D158")
        case 40...60:  return Color(hex: "FF9F0A")
        case 20...40:  return Color(hex: "FF6B0A")
        default:       return Color(hex: "FF453A")
        }
    }
}

// MARK: - Vitals grid

struct VitalsGrid: View {
    let result: PulseScanResult

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            VitalCard(label: "HRV",
                      value: "\(result.rmssd.safeInt)",
                      unit: "ms",
                      note: hrvNote,
                      noteColor: Color(hex: "34C759"))
            VitalCard(label: "Breathing",
                      value: "\(result.breathingRate.safeInt)",
                      unit: "/min",
                      note: breathNote,
                      noteColor: breathColor)
            VitalCard(label: "Stress",
                      value: "\((100 - result.recoveryScore).safeInt)",
                      unit: "/100",
                      note: stressNote,
                      noteColor: stressColor)
            VitalCard(label: "Wellness",
                      value: "\(result.wellnessScore.safeInt)",
                      unit: "/100",
                      note: wellnessNote,
                      noteColor: Color(hex: "34C759"))
        }
    }

    var hrvNote: String {
        let r = result.rmssd
        if r > 50 { return "Excellent" }
        if r > 30 { return "Good" }
        if r > 20 { return "Moderate" }
        return "Low"
    }

    var breathNote: String {
        let b = result.breathingRate
        if b < 12 { return "Very calm" }
        if b <= 16 { return "Normal" }
        if b <= 20 { return "Elevated" }
        return "High"
    }

    var breathColor: Color {
        let b = result.breathingRate
        if b <= 16 { return Color(hex: "34C759") }
        if b <= 20 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }

    var stressNote: String {
        let s = 100 - result.recoveryScore
        if s < 30 { return "Low" }
        if s < 60 { return "Moderate" }
        return "High"
    }

    var stressColor: Color {
        let s = 100 - result.recoveryScore
        if s < 30 { return Color(hex: "34C759") }
        if s < 60 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }

    var wellnessNote: String {
        let w = result.wellnessScore
        if w >= 80 { return "Great" }
        if w >= 60 { return "Good" }
        if w >= 40 { return "Fair" }
        return "Needs rest"
    }
}

struct VitalCard: View {
    let label: String
    let value: String
    let unit: String
    let note: String
    let noteColor: Color

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
            Text(note)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(noteColor)
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

// MARK: - Glucose card

struct GlucoseResultCard: View {
    let result: PulseScanResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(glucoseIconBg)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(glucoseColor.opacity(0.3),
                                    lineWidth: 0.5)
                    )
                Image(systemName: glucoseIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(glucoseColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(glucoseTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(result.glucoseMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "48484a"))
                Text("Experimental — trend only, not clinical")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "2a2a2a"))
            }

            Spacer()
        }
        .padding(16)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }

    var glucoseColor: Color {
        switch result.glucoseTrend {
        case .rising:       return Color(hex: "FF9F0A")
        case .falling:      return Color(hex: "378ADD")
        case .stable:       return Color(hex: "34C759")
        case .inconclusive: return Color(hex: "48484a")
        }
    }

    var glucoseIconBg: Color {
        switch result.glucoseTrend {
        case .rising:       return Color(hex: "2b1a0d")
        case .falling:      return Color(hex: "0d1a2b")
        case .stable:       return Color(hex: "0d2b1a")
        case .inconclusive: return Color(hex: "222222")
        }
    }

    var glucoseIcon: String {
        switch result.glucoseTrend {
        case .rising:       return "arrow.up.circle.fill"
        case .falling:      return "arrow.down.circle.fill"
        case .stable:       return "minus.circle.fill"
        case .inconclusive: return "questionmark.circle.fill"
        }
    }

    var glucoseTitle: String {
        switch result.glucoseTrend {
        case .rising:       return "Glucose trending up"
        case .falling:      return "Glucose trending down"
        case .stable:       return "Glucose stable"
        case .inconclusive: return "Not enough data"
        }
    }
}

// MARK: - Message card

struct MessageCard: View {
    let result: PulseScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "34C759"))
                Text("What this means")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "48484a"))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }

            Text(result.wellnessMessage)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "636366"))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
        )
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 7)
    }
}

struct FaceVitalsGrid: View {
    let result: PulseScanResult

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            VitalCard(label: "Heart rate",
                      value: "\(result.heartRate.safeInt)",
                      unit: "BPM",
                      note: "From face scan",
                      noteColor: Color(hex: "5E5CE6"))
            VitalCard(label: "Breathing",
                      value: "\(result.breathingRate.safeInt)",
                      unit: "/min",
                      note: breathNote,
                      noteColor: Color(hex: "34C759"))
            VitalCard(label: "Stress",
                      value: "\((100 - result.recoveryScore).safeInt)",
                      unit: "/100",
                      note: "Estimated",
                      noteColor: Color(hex: "5E5CE6"))
            VitalCard(label: "Wellness",
                      value: "\(result.wellnessScore.safeInt)",
                      unit: "/100",
                      note: wellnessNote,
                      noteColor: Color(hex: "34C759"))
        }
    }

    var breathNote: String {
        let b = result.breathingRate
        if b <= 16 { return "Normal" }
        if b <= 20 { return "Elevated" }
        return "High"
    }

    var wellnessNote: String {
        let w = result.wellnessScore
        if w >= 80 { return "Great" }
        if w >= 60 { return "Good" }
        return "Fair"
    }
}


// MARK: - Recovery level label

extension RecoveryLevel {
    var label: String {
        switch self {
        case .peak:     return "Peak"
        case .good:     return "Good"
        case .moderate: return "Moderate"
        case .low:      return "Low"
        case .depleted: return "Depleted"
        }
    }
}
extension Float {
    var safeInt: Int {
        guard self.isFinite else { return 0 }
        return Int(max(0, min(self, 10000)))
    }
}
