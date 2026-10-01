import Foundation
import Testing
@testable import Pomo

struct SessionAnalyticsTests {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    private func session(start: Date, end: Date, seconds: Int, task: String = "Writing",
                         category: String = "Work", intervals: [FocusInterval]? = nil) -> FocusSession {
        FocusSession(startedAt: start, endedAt: end, plannedSeconds: 1800,
                     focusedSeconds: seconds, task: task, checkpoints: [], completed: true,
                     category: category, intervals: intervals)
    }

    @Test func legacyHistoryLoadsAsFocusAndRoundTrips() throws {
        let original = session(start: date(1, 9), end: date(1, 9, 25), seconds: 1500)
        var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        payload.removeValue(forKey: "category")
        payload.removeValue(forKey: "intervals")
        let legacy = try JSONDecoder().decode(FocusSession.self, from: JSONSerialization.data(withJSONObject: payload))
        #expect(legacy.category == "Focus")
        #expect(legacy.intervals == nil)
        #expect(legacy.id == original.id)
        #expect(legacy.focusedSeconds == 1500)
        #expect(try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(legacy)) == legacy)
    }

    @Test func newHistoryPreservesCategoryAndIntervals() throws {
        let start = date(1, 9)
        let end = date(1, 9, 25)
        let original = session(start: start, end: end, seconds: 1500, category: "Research",
                               intervals: [FocusInterval(startedAt: start, endedAt: end)])
        let decoded = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func midnightIsSplitAcrossActualDays() {
        let start = date(1, 23, 50)
        let end = date(2, 0, 10)
        let block = session(start: start, end: end, seconds: 1200,
                            intervals: [FocusInterval(startedAt: start, endedAt: end)])
        let firstDay = SessionAnalytics.activities(on: start, sessions: [block], calendar: calendar)
        let secondDay = SessionAnalytics.activities(on: end, sessions: [block], calendar: calendar)
        #expect(firstDay.map(\.seconds) == [600])
        #expect(secondDay.map(\.seconds) == [600])
        #expect(firstDay.first?.endedAt == date(2, 0))
        #expect(secondDay.first?.startedAt == date(2, 0))
        #expect(SessionAnalytics.activities(on: date(3, 0), sessions: [block], calendar: calendar).isEmpty)
    }

    @Test func pausesAreGapsAndDoNotCountAsWork() {
        let block = session(start: date(1, 9), end: date(1, 10), seconds: 1800, intervals: [
            FocusInterval(startedAt: date(1, 9), endedAt: date(1, 9, 15)),
            FocusInterval(startedAt: date(1, 9, 45), endedAt: date(1, 10))
        ])
        let result = SessionAnalytics.activities(on: date(1, 0), sessions: [block], calendar: calendar)
        #expect(result.count == 2)
        #expect(result.map(\.seconds) == [900, 900])
        #expect(result[0].endedAt < result[1].startedAt)
        #expect(result.allSatisfy { !$0.isEstimated })
    }

    @Test func roundingPreservesTotalAcrossMidnight() {
        let start = date(1, 23, 59, 59)
        let end = date(2, 0, 0, 2)
        let block = session(start: start, end: end, seconds: 2,
                            intervals: [FocusInterval(startedAt: start, endedAt: end)])
        let first = SessionAnalytics.activities(on: start, sessions: [block], calendar: calendar)
        let second = SessionAnalytics.activities(on: end, sessions: [block], calendar: calendar)
        #expect((first + second).reduce(0) { $0 + $1.seconds } == 2)
    }

    @Test func legacyTimingRetainsFocusTotalAndIsMarkedEstimated() {
        let block = session(start: date(1, 23), end: date(2, 1), seconds: 1800)
        let first = SessionAnalytics.activities(on: date(1, 0), sessions: [block], calendar: calendar)
        let second = SessionAnalytics.activities(on: date(2, 0), sessions: [block], calendar: calendar)
        #expect(first.map(\.seconds) == [900])
        #expect(second.map(\.seconds) == [900])
        #expect((first + second).allSatisfy { $0.isEstimated })
    }

    @Test func allocationsMergeRepeatedTasksAndSeparateTypes() {
        let blocks = [
            session(start: date(1, 9), end: date(1, 9, 10), seconds: 600),
            session(start: date(1, 10), end: date(1, 10, 20), seconds: 1200, category: "Study"),
            session(start: date(1, 11), end: date(1, 11, 10), seconds: 600, task: "  ")
        ]
        let activities = SessionAnalytics.activities(on: date(1, 0), sessions: blocks, calendar: calendar)
        let tasks = SessionAnalytics.allocations(activities, by: .task)
        #expect(tasks.map(\.name) == ["Writing", "Untitled focus"])
        #expect(tasks.map(\.seconds) == [1800, 600])
        let types = SessionAnalytics.allocations(activities, by: .category)
        #expect(types.count == 2)
        #expect(types.reduce(0) { $0 + $1.seconds } == 2400)
    }

    @Test func emptyAndInvalidIntervalsDoNotCreateChartEntries() {
        let zero = session(start: date(1, 9), end: date(1, 9, 10), seconds: 0)
        let invalid = session(start: date(1, 9), end: date(1, 9), seconds: 60)
        #expect(SessionAnalytics.activities(on: date(1, 0), sessions: [zero, invalid], calendar: calendar).isEmpty)
    }

    @Test func daylightSavingDayUsesCalendarBoundaries() throws {
        var dstCalendar = calendar
        dstCalendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let start = try #require(dstCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let end = try #require(dstCalendar.date(byAdding: .day, value: 1, to: start))
        let block = session(start: start, end: end, seconds: 90000,
                            intervals: [FocusInterval(startedAt: start, endedAt: end)])
        let activities = SessionAnalytics.activities(on: start, sessions: [block], calendar: dstCalendar)
        #expect(end.timeIntervalSince(start) == 25 * 3600)
        #expect(activities.map(\.seconds) == [90000])
        #expect(SessionAnalytics.activities(on: end, sessions: [block], calendar: dstCalendar).isEmpty)
    }
}

@MainActor
struct TimerStoreAnalyticsTests {
    private final class Clock { var date = Date() }

    @Test func currentPausedAndSavedTimeStayConsistent() throws {
        let suite = "pomo.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = Clock()
        let store = TimerStore(defaults: defaults, now: { clock.date })
        store.task = "Build chart"
        store.category = "Work"
        store.start()
        #expect(!store.canEditTask)
        clock.date += 30
        store.handleAppBecameActive()
        #expect(store.focusedSecondsToday == 30)
        #expect(store.activities(on: clock.date).first?.isCurrent == true)
        store.pause()
        clock.date += 120
        #expect(store.focusedSecondsToday == 30)
        store.start()
        clock.date += 45
        store.pause()
        #expect(store.focusedSecondsToday == 75)
        #expect(store.activities(on: clock.date).count == 2)
        store.finishEarly()
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.category == "Work")
        #expect(store.sessions.first?.intervals?.count == 2)
        #expect(store.focusedSecondsToday == 75)
        #expect(store.activities(on: clock.date).allSatisfy { !$0.isCurrent })
        store.skipBreak()
        #expect(store.canEditTask)
        let restored = TimerStore(defaults: defaults, now: { clock.date })
        #expect(restored.sessions == store.sessions)
        #expect(restored.focusedSecondsToday == 75)
    }

    @Test func customTypesAreTrimmedDeduplicatedAndPersisted() throws {
        let suite = "pomo.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TimerStore(defaults: defaults)
        #expect(store.category == "Focus")
        store.selectCustomCategory(" Research  ")
        store.selectCustomCategory("research")
        #expect(store.category == "Research")
        #expect(store.categories.filter { $0.lowercased() == "research" }.count == 1)
        store.selectCustomCategory("   ")
        #expect(store.category == "Research")
        let restored = TimerStore(defaults: defaults)
        #expect(restored.categories.contains("Research"))
        store.selectCustomCategory("focus")
        #expect(store.category == "Focus")
    }

    @Test func finishingWhileRunningKeepsTheFinalInterval() throws {
        let suite = "pomo.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = Clock()
        let store = TimerStore(defaults: defaults, now: { clock.date })
        store.task = "First task"
        store.category = "Study"
        store.start()
        clock.date += 20
        store.pause()
        clock.date += 60
        store.start()
        clock.date += 30
        store.handleAppBecameActive()
        // Attribution belongs to the block captured at start, even if another caller edits the draft.
        store.task = "Next task"
        store.category = "Work"
        store.finishEarly()
        let saved = try #require(store.sessions.first)
        #expect(saved.focusedSeconds == 50)
        #expect(saved.endedAt == clock.date)
        #expect(saved.intervals?.count == 2)
        #expect(saved.task == "First task")
        #expect(saved.category == "Study")
        #expect(store.focusedSecondsToday == 50)
        store.skipBreak()
    }

    @Test func resetDiscardsCurrentIntervalsBeforeTheNextBlock() throws {
        let suite = "pomo.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = Clock()
        let store = TimerStore(defaults: defaults, now: { clock.date })
        store.start()
        clock.date += 20
        store.handleAppBecameActive()
        store.reset()
        #expect(store.focusedSecondsToday == 0)
        #expect(store.canEditTask)
        store.start()
        clock.date += 10
        store.pause()
        store.finishEarly()
        #expect(store.sessions.first?.focusedSeconds == 10)
        #expect(store.sessions.first?.intervals?.count == 1)
        #expect(store.focusedSecondsToday == 10)
        store.skipBreak()
    }
}
