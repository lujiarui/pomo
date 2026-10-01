import Foundation

enum AllocationGrouping: String, CaseIterable, Identifiable {
    case category = "Type"
    case task = "Task"
    var id: String { rawValue }
}

struct TimeAllocation: Identifiable {
    var name: String
    var seconds: Int
    var id: String { name }
}

struct DailyActivity: Identifiable {
    var id: UUID
    var sessionID: UUID
    var startedAt: Date
    var endedAt: Date
    var seconds: Int
    var task: String
    var category: String
    var isEstimated: Bool
    var isCurrent: Bool
}

enum SessionAnalytics {
    /// Distribute recorded focus seconds over the active intervals, clipping at day boundaries.
    /// Cumulative rounding keeps the total unchanged when a session spans multiple days.
    static func activities(on date: Date, sessions: [FocusSession], currentSessionID: UUID? = nil,
                           calendar: Calendar = .current) -> [DailyActivity] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
        return sessions.flatMap { session -> [DailyActivity] in
            guard session.focusedSeconds > 0 else { return [] }
            let intervals = (session.intervals ?? [FocusInterval(
                id: session.id, startedAt: session.startedAt, endedAt: session.endedAt
            )]).filter { $0.endedAt > $0.startedAt }.sorted { $0.startedAt < $1.startedAt }
            let duration = intervals.reduce(0.0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
            guard duration > 0 else { return [] }
            var offset = 0.0
            return intervals.compactMap { interval in
                let intervalDuration = interval.endedAt.timeIntervalSince(interval.startedAt)
                defer { offset += intervalDuration }
                let start = max(interval.startedAt, day.start)
                let end = min(interval.endedAt, day.end)
                guard end > start else { return nil }
                func secondsThrough(_ boundary: Date) -> Int {
                    let fraction = (offset + boundary.timeIntervalSince(interval.startedAt)) / duration
                    return min(session.focusedSeconds, Int((Double(session.focusedSeconds) * fraction).rounded(.down)))
                }
                let seconds = secondsThrough(end) - secondsThrough(start)
                guard seconds > 0 else { return nil }
                return DailyActivity(
                    id: interval.id, sessionID: session.id, startedAt: start, endedAt: end,
                    seconds: seconds, task: session.taskTitle, category: session.category,
                    isEstimated: session.intervals == nil, isCurrent: session.id == currentSessionID
                )
            }
        }.sorted { $0.startedAt < $1.startedAt }
    }

    static func allocations(_ activities: [DailyActivity], by grouping: AllocationGrouping) -> [TimeAllocation] {
        let groups = Dictionary(grouping: activities) { grouping == .category ? $0.category : $0.task }
        return groups.map { TimeAllocation(name: $0.key, seconds: $0.value.reduce(0) { $0 + $1.seconds }) }
            .sorted { $0.seconds == $1.seconds ? $0.name < $1.name : $0.seconds > $1.seconds }
    }
}
