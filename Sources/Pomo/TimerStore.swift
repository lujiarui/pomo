import AppKit
import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class TimerStore: ObservableObject {
    @Published var phase: TimerPhase = .focus
    @Published var isRunning = false
    @Published var remainingSeconds = 25 * 60
    @Published var elapsedSeconds = 0
    @Published var task = ""
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
    private var isLoading = true

    private let sessionsKey = "pomo.sessions.v1"
    private let settingsKey = "pomo.settings.v1"

    init() {
        let defaults = UserDefaults.standard
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

    deinit { ticker?.invalidate() }

    var plannedSeconds: Int { duration(for: phase) }

    var progress: Double {
        guard plannedSeconds > 0 else { return 0 }
        return min(1, max(0, Double(elapsedSeconds) / Double(plannedSeconds)))
    }

    var latestCheckpoint: Checkpoint? {
        phase == .focus ? currentCheckpoints.last : sessions.first?.checkpoints.last
    }

    var completedFocusCountToday: Int {
        sessions.filter { Calendar.current.isDateInToday($0.endedAt) && $0.completed }.count
    }

    var focusedSecondsToday: Int {
        sessions.filter { Calendar.current.isDateInToday($0.endedAt) }.reduce(0) { $0 + $1.focusedSeconds }
    }

    var focusedSecondsThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return sessions.filter { interval.contains($0.endedAt) }.reduce(0) { $0 + $1.focusedSeconds }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(sessions.filter { $0.focusedSeconds >= 60 }.map { calendar.startOfDay(for: $0.endedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
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
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let total = sessions.filter { $0.endedAt >= day && $0.endedAt < next }.reduce(0) { $0 + $1.focusedSeconds }
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
        guard remainingSeconds > 0 else { return }
        if startedAt == nil { startedAt = Date() }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
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
        let secondsLeft = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        remainingSeconds = secondsLeft
        elapsedSeconds = min(plannedSeconds, plannedSeconds - secondsLeft)
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
        let now = Date()
        sessions.insert(FocusSession(
            startedAt: startedAt ?? now.addingTimeInterval(-TimeInterval(elapsedSeconds)),
            endedAt: now,
            plannedSeconds: plannedSeconds,
            focusedSeconds: elapsedSeconds,
            task: task.trimmingCharacters(in: .whitespacesAndNewlines),
            checkpoints: currentCheckpoints,
            completed: completed
        ), at: 0)
        saveSessions()
    }

    private func clearCurrentState(keepTask: Bool, keepCheckpointDraft: Bool) {
        remainingSeconds = duration(for: phase)
        elapsedSeconds = 0
        startedAt = nil
        endDate = nil
        currentCheckpoints = []
        if !keepCheckpointDraft { checkpointDraft = "" }
        if !keepTask { task = "" }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        endDate = nil
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
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
