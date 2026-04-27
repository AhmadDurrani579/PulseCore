//
//  ReadingsStore.swift
//  PulseCore
//
//  Created by Ahmad on 20/04/2026.
//


import Foundation
import PulseCore
import Combine

class ReadingsStore: ObservableObject {

    static let shared = ReadingsStore()

    @Published var readings: [SavedReading] = []

    private let key = "pulsecore_readings"

    init() {
        load()
    }

    func save(_ result: PulseScanResult) {
        let reading = SavedReading(result: result)
        readings.insert(reading, at: 0)
        // Keep max 90 days
        if readings.count > 90 {
            readings = Array(readings.prefix(90))
        }
        persist()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(
                  [SavedReading].self, from: data)
        else { return }
        readings = saved
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(readings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    var lastReading: SavedReading? {
        readings.first
    }
}

// MARK: - SavedReading

struct SavedReading: Codable, Identifiable {
    let id: UUID
    let date: Date
    let heartRate: Float
    let rmssd: Float
    let sdnn: Float
    let breathingRate: Float
    let recoveryScore: Float
    let wellnessScore: Float
    let rhythmStatus: Int
    let glucoseTrend: Int
    let isFromFaceScan: Bool

    init(result: PulseScanResult) {
        self.id            = UUID()
        self.date          = Date()
        self.heartRate     = result.heartRate.isFinite ? result.heartRate : 0
        self.rmssd         = result.rmssd.isFinite ? result.rmssd : 0
        self.sdnn          = result.sdnn.isFinite ? result.sdnn : 0
        self.breathingRate = result.breathingRate.isFinite ? result.breathingRate : 0
        self.recoveryScore = result.recoveryScore.isFinite ? result.recoveryScore : 0
        self.wellnessScore = result.wellnessScore.isFinite ? result.wellnessScore : 0
        self.rhythmStatus  = result.rhythmStatus == .normal ? 0 :
                             result.rhythmStatus == .irregular ? 1 : 2
        self.glucoseTrend  = result.glucoseTrend == .rising ? 0 :
                             result.glucoseTrend == .falling ? 1 :
                             result.glucoseTrend == .stable ? 2 : 3
        self.isFromFaceScan = result.isFromFaceScan
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · HH:mm"
        return f.string(from: date)
    }
}
