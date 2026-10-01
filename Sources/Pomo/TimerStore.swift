import AppKit
import Combine
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class TimerStore: ObservableObject {
    @Published var phase: TimerPhase = .focus
    @Published var isRunning = false
    @Published var remainingSeconds = 25 * 60
    @Published var elapsedSeconds = 0
    @Published var task = ""
    @Published var category = "Focus"
    @Published private(set) var customCategories: [String] = []
    @Published private(set) var categoryAppearances: [String: FocusTypeAppearance] = [:]
    @Published var checkpointDraft = ""
    @Published var currentCheckpoints: [Checkpoint] = []
    @Published var breakNotesForNextFocus: [Checkpoint] = []
    @Published var sessions: [FocusSession] = []
    @Published var settings = PomoSettings() {
        didSet {
            guard !isLoading else { return }
            saveSettings()
            if !isRunning && elapsedSeconds == 0 {
                remainingSeconds = duration(for: phase)
            }
        }
    }

    var onBreakStarted: (() -> Void)?
    var onBreakEnded: (() -> Void)?
    var onFocusStarted: (() -> Void)?

    private var ticker: Timer?
    private var endDate: Date?
    private var startedAt: Date?
    private var activeInterval: (id: UUID, startedAt: Date)?
    private var focusIntervals: [FocusInterval] = []
    private var currentSessionID = UUID()
    private var sessionTask = ""
    private var sessionCategory = "Focus"
    private var isLoading = true
    private let defaults: UserDefaults
    private let now: () -> Date

    private let sessionsKey = "pomo.sessions.v1"
    private let settingsKey = "pomo.settings.v1"
    private let categoriesKey = "pomo.categories.v1"
    private let categoryAppearancesKey = "pomo.categoryAppearances.v1"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        customCategories = defaults.stringArray(forKey: categoriesKey) ?? []
        if let data = defaults.data(forKey: categoryAppearancesKey),
           let decoded = try? JSONDecoder().decode([String: FocusTypeAppearance].self, from: data) {
            categoryAppearances = decoded.filter {
                !FocusTypeAppearance.builtInNames.contains($0.key)
                    && $0.value.emoji.map(FocusTypeAppearance.isSingleEmoji) == true
            }
        }
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(PomoSettings.self, from: data) {
            settings = decoded
        }
        if let data = defaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = decoded.sorted { $0.endedAt > $1.endedAt }
        }
        remainingSeconds = settings.focusMinutes * 60
        isLoading = false
    }

    isolated deinit { ticker?.invalidate() }

    var plannedSeconds: Int { duration(for: phase) }

    var canEditTask: Bool { phase == .focus && startedAt == nil }

    var categories: [String] {
        var result = FocusTypeAppearance.builtInNames
        for name in customCategories + sessions.map(\.category) + [category] where !result.contains(name) {
            result.append(name)
        }
        return result
    }

    var currentTint: Color {
        phase == .breakTime ? TimerPhase.breakTime.color : categoryColor(category)
    }

    func categoryAppearance(_ name: String) -> FocusTypeAppearance {
        categoryAppearances[name] ?? .standard(for: name)
    }

    func categoryColor(_ name: String) -> Color { categoryAppearance(name).color.color }

    @discardableResult
    func selectCustomCategory(_ name: String, emoji: String? = nil, color: FocusTypeColor? = nil) -> Bool {
        guard canEditTask else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let emoji, !FocusTypeAppearance.isSingleEmoji(emoji) { return false }
        if let existing = categories.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            category = existing
        } else {
            customCategories.append(trimmed)
            defaults.set(customCategories, forKey: categoriesKey)
            category = trimmed
        }
        if !FocusTypeAppearance.builtInNames.contains(category), emoji != nil || color != nil {
            let current = categoryAppearance(category)
            categoryAppearances[category] = FocusTypeAppearance(
                emoji: emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? current.emoji,
                color: color ?? current.color
            )
            if let data = try? JSONEncoder().encode(categoryAppearances) {
                defaults.set(data, forKey: categoryAppearancesKey)
            }
        }
        return true
    }

    /// Include the current block so today's charts update as work is recorded.
    private var analyticsSessions: [FocusSession] {
        guard phase == .focus, elapsedSeconds > 0, let startedAt else { return sessions }
        return sessions + [FocusSession(
            id: currentSessionID, startedAt: startedAt, endedAt: now(), plannedSeconds: plannedSeconds,
            focusedSeconds: elapsedSeconds, task: sessionTask, checkpoints: currentCheckpoints,
            completed: false, category: sessionCategory, intervals: recordedIntervals
        )]
    }

    private var recordedIntervals: [FocusInterval] {
        var result = focusIntervals
        if let activeInterval {
            let end = min(now(), endDate ?? now())
            if end > activeInterval.startedAt {
                result.append(FocusInterval(id: activeInterval.id, startedAt: activeInterval.startedAt, endedAt: end))
            }
        }
        return result
    }

    func activities(on date: Date) -> [DailyActivity] {
        SessionAnalytics.activities(on: date, sessions: analyticsSessions, currentSessionID: currentSessionID)
    }

    var progress: Double {
        guard plannedSeconds > 0 else { return 0 }
        return min(1, max(0, Double(elapsedSeconds) / Double(plannedSeconds)))
    }

    var latestCheckpoint: Checkpoint? {
        phase == .focus ? currentCheckpoints.last : sessions.first?.checkpoints.last
    }

    var completedFocusCountToday: Int {
        sessions.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: now()) && $0.completed }.count
    }

    var focusedSecondsToday: Int {
        activities(on: now()).reduce(0) { $0 + $1.seconds }
    }

    var focusedSecondsThisWeek: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now()) else { return 0 }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
            .reduce(0) { total, day in total + activities(on: day).reduce(0) { $0 + $1.seconds } }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for session in analyticsSessions where session.focusedSeconds > 0 {
            var day = calendar.startOfDay(for: session.startedAt)
            let lastDay = calendar.startOfDay(for: session.endedAt)
            while day <= lastDay {
                totals[day, default: 0] += SessionAnalytics.activities(on: day, sessions: [session]).reduce(0) { $0 + $1.seconds }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        let days = Set(totals.filter { $0.value >= 60 }.map(\.key))
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now())
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) {
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var lastSevenDays: [DaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = activities(on: day).reduce(0) { $0 + $1.seconds }
            return DaySummary(date: day, seconds: total)
        }
    }

    func duration(for phase: TimerPhase) -> Int {
        switch phase {
        case .focus: return settings.focusMinutes * 60
        case .breakTime: return settings.breakMinutes * 60
        }
    }

    func toggleTimer() {
        guard phase == .focus else { return }
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning, remainingSeconds > 0 else { return }
        let start = now()
        if startedAt == nil {
            startedAt = start
            sessionTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
            sessionCategory = category
        }
        if phase == .focus { activeInterval = (UUID(), start) }
        isRunning = true
        endDate = start.addingTimeInterval(TimeInterval(remainingSeconds))
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        ticker?.tolerance = 0.08
        if phase == .focus { onFocusStarted?() }
    }

    func pause() {
        guard isRunning, phase == .focus else { return }
        updateClock()
        guard phase == .focus else { return }
        stopTicker()
    }

    func reset() {
        guard phase == .focus else {
            skipBreak()
            return
        }
        stopTicker()
        clearCurrentState(keepTask: true, keepCheckpointDraft: false)
    }

    /// Stop work, save the boundary checkpoint, and immediately begin the break.
    func finishEarly() {
        guard phase == .focus, elapsedSeconds > 0 else { return }
        if isRunning { updateClock() }
        guard phase == .focus else { return }
        beginBreak(completed: false)
    }

    /// Return to a fresh, stopped focus timer. Starting the next block remains explicit.
    func skipBreak() {
        guard phase == .breakTime else { return }
        stopTicker()
        phase = .focus
        clearCurrentState(keepTask: true, keepCheckpointDraft: false)
        onBreakEnded?()
    }

    /// Add a resume note to the work checkpoint while its break is active.
    func addCheckpoint() {
        let trimmed = checkpointDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .breakTime, !trimmed.isEmpty, !sessions.isEmpty else { return }
        let note = Checkpoint(elapsedSeconds: sessions[0].focusedSeconds, note: trimmed)
        sessions[0].checkpoints.append(note)
        breakNotesForNextFocus.append(note)
        checkpointDraft = ""
        saveSessions()
    }

    func deleteSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        saveSessions()
    }

    func clearHistory() {
        sessions = []
        saveSessions()
    }

    func handleAppBecameActive() {
        if isRunning { updateClock() }
    }

    private func tick() { updateClock() }

    private func updateClock() {
        guard isRunning, let endDate else { return }
        let secondsLeft = max(0, Int(ceil(endDate.timeIntervalSince(now()))))
        if remainingSeconds != secondsLeft { remainingSeconds = secondsLeft }
        let elapsed = min(plannedSeconds, plannedSeconds - secondsLeft)
        if elapsedSeconds != elapsed { elapsedSeconds = elapsed }
        if secondsLeft == 0 { completeCurrentTimer() }
    }

    private func completeCurrentTimer() {
        let finishedPhase = phase
        stopTicker()
        elapsedSeconds = plannedSeconds
        remainingSeconds = 0

        if finishedPhase == .focus {
            notifyCompletion(of: .focus)
            beginBreak(completed: true)
        } else {
            notifyCompletion(of: .breakTime)
            phase = .focus
            clearCurrentState(keepTask: true, keepCheckpointDraft: false)
            onBreakEnded?()
            // The next focus block stays stopped until the user resumes it.
        }
    }

    private func beginBreak(completed: Bool) {
        guard phase == .focus else { return }
        breakNotesForNextFocus = []
        createBoundaryCheckpoint(completed: completed)
        saveCurrentSession(completed: completed)
        stopTicker()
        phase = .breakTime
        clearCurrentState(keepTask: true, keepCheckpointDraft: false)
        start()
        onBreakStarted?()
    }

    private func createBoundaryCheckpoint(completed: Bool) {
        let draft = checkpointDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskName = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let note: String
        if !draft.isEmpty {
            note = draft
        } else if !taskName.isEmpty {
            note = completed ? "Completed: \(taskName)" : "Stopped: \(taskName)"
        } else {
            note = completed ? "Focus completed" : "Work stopped"
        }
        currentCheckpoints.append(Checkpoint(elapsedSeconds: elapsedSeconds, note: note))
    }

    private func saveCurrentSession(completed: Bool) {
        guard phase == .focus, elapsedSeconds > 0 else { return }
        let intervals = recordedIntervals
        let finish = intervals.last?.endedAt ?? now()
        sessions.insert(FocusSession(
            id: currentSessionID,
            startedAt: startedAt ?? finish.addingTimeInterval(-TimeInterval(elapsedSeconds)),
            endedAt: finish,
            plannedSeconds: plannedSeconds,
            focusedSeconds: elapsedSeconds,
            task: sessionTask,
            checkpoints: currentCheckpoints,
            completed: completed,
            category: sessionCategory,
            intervals: intervals
        ), at: 0)
        saveSessions()
    }

    private func clearCurrentState(keepTask: Bool, keepCheckpointDraft: Bool) {
        remainingSeconds = duration(for: phase)
        elapsedSeconds = 0
        startedAt = nil
        activeInterval = nil
        focusIntervals = []
        currentSessionID = UUID()
        endDate = nil
        currentCheckpoints = []
        if !keepCheckpointDraft { checkpointDraft = "" }
        if !keepTask { task = "" }
    }

    private func stopTicker() {
        if phase == .focus {
            focusIntervals = recordedIntervals
            activeInterval = nil
        }
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        endDate = nil
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: sessionsKey)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    private func notifyCompletion(of phase: TimerPhase) {
        if settings.playSound { NSSound(named: "Glass")?.play() }
        let breakMinutes = settings.breakMinutes
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { allowed, _ in
            guard allowed else { return }
            let content = UNMutableNotificationContent()
            content.title = phase == .focus ? "Focus complete — break started" : "Break complete"
            content.body = phase == .focus
                ? "Your checkpoint was saved. Step away for \(breakMinutes) minutes."
                : "The next focus block is ready when you are."
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}
