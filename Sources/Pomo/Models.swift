import Foundation
import SwiftUI

enum TimerPhase: String, Codable, CaseIterable, Identifiable {
    case focus
    case breakTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .breakTime: return "Break"
        }
    }

    var compactTitle: String {
        switch self {
        case .focus: return "Focus"
        case .breakTime: return "Break"
        }
    }

    var color: Color {
        switch self {
        case .focus: return Color(red: 0.93, green: 0.36, blue: 0.31)
        case .breakTime: return Color(red: 0.25, green: 0.66, blue: 0.54)
        }
    }
}

struct Checkpoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var elapsedSeconds: Int
    var note: String
}

struct FocusSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int
    var focusedSeconds: Int
    var task: String
    var checkpoints: [Checkpoint]
    var completed: Bool
}

struct PomoSettings: Codable, Equatable {
    var focusMinutes = 25
    var breakMinutes = 5
    var dailyGoalMinutes = 120
    var playSound = true

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, breakMinutes, shortBreakMinutes, dailyGoalMinutes, playSound
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
        breakMinutes = try values.decodeIfPresent(Int.self, forKey: .breakMinutes)
            ?? values.decodeIfPresent(Int.self, forKey: .shortBreakMinutes)
            ?? 5
        dailyGoalMinutes = try values.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 120
        playSound = try values.decodeIfPresent(Bool.self, forKey: .playSound) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(focusMinutes, forKey: .focusMinutes)
        try values.encode(breakMinutes, forKey: .breakMinutes)
        try values.encode(dailyGoalMinutes, forKey: .dailyGoalMinutes)
        try values.encode(playSound, forKey: .playSound)
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case timer
    case checkpoints
    case statistics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .checkpoints: return "Checkpoints"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .checkpoints: return "flag"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct DaySummary: Identifiable {
    var date: Date
    var seconds: Int
    var id: Date { date }
}
