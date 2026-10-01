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
    var category = "Focus"
    /// Nil means a legacy session whose pause intervals were not recorded.
    var intervals: [FocusInterval]? = nil

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, plannedSeconds, focusedSeconds, task, checkpoints, completed, category, intervals
    }

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date, plannedSeconds: Int,
         focusedSeconds: Int, task: String, checkpoints: [Checkpoint], completed: Bool,
         category: String = "Focus", intervals: [FocusInterval]? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.focusedSeconds = focusedSeconds
        self.task = task
        self.checkpoints = checkpoints
        self.completed = completed
        self.category = category
        self.intervals = intervals
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        plannedSeconds = try values.decode(Int.self, forKey: .plannedSeconds)
        focusedSeconds = try values.decode(Int.self, forKey: .focusedSeconds)
        task = try values.decode(String.self, forKey: .task)
        checkpoints = try values.decode([Checkpoint].self, forKey: .checkpoints)
        completed = try values.decode(Bool.self, forKey: .completed)
        category = try values.decodeIfPresent(String.self, forKey: .category) ?? "Focus"
        intervals = try values.decodeIfPresent([FocusInterval].self, forKey: .intervals)
    }

    var taskTitle: String {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled focus" : trimmed
    }
}

struct FocusInterval: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
}

struct PomoSettings: Codable, Equatable {
    var focusMinutes = 25
    var breakMinutes = 5
    var dailyGoalMinutes = 120
    var playSound = true
    var breakBuddy: BreakBuddy = .mochi
    var breakBuddySize = 128.0
    static let breakBuddySizeRange = 64.0...192.0

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, breakMinutes, shortBreakMinutes, dailyGoalMinutes, playSound, breakBuddy, breakBuddySize
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
        let buddyName = try values.decodeIfPresent(String.self, forKey: .breakBuddy)
        breakBuddy = buddyName.flatMap(BreakBuddy.init(rawValue:)) ?? .mochi
        let size = try values.decodeIfPresent(Double.self, forKey: .breakBuddySize) ?? 128
        breakBuddySize = min(Self.breakBuddySizeRange.upperBound, max(Self.breakBuddySizeRange.lowerBound, size))
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(focusMinutes, forKey: .focusMinutes)
        try values.encode(breakMinutes, forKey: .breakMinutes)
        try values.encode(dailyGoalMinutes, forKey: .dailyGoalMinutes)
        try values.encode(playSound, forKey: .playSound)
        try values.encode(breakBuddy, forKey: .breakBuddy)
        try values.encode(breakBuddySize, forKey: .breakBuddySize)
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case timer
    case checkpoints
    case statistics
    case timeline
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .checkpoints: return "Checkpoints"
        case .statistics: return "Statistics"
        case .timeline: return "Timeline"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .checkpoints: return "flag"
        case .statistics: return "chart.bar.xaxis"
        case .timeline: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct DaySummary: Identifiable {
    var date: Date
    var seconds: Int
    var id: Date { date }
}
