import AppKit
import Foundation
import Testing
@testable import Pomo

struct BreakBuddyTests {
    @Test func oldAndUnknownSettingsKeepExistingPreferences() throws {
        let oldData = Data(#"{"focusMinutes":32,"shortBreakMinutes":9,"dailyGoalMinutes":175,"playSound":false}"#.utf8)
        let old = try JSONDecoder().decode(PomoSettings.self, from: oldData)
        #expect(old.breakBuddy == .mochi)
        #expect(old.breakBuddySize == 128)
        #expect(old.focusMinutes == 32)
        #expect(old.breakMinutes == 9)
        #expect(old.dailyGoalMinutes == 175)
        #expect(!old.playSound)
        let unknownData = Data(#"{"breakBuddy":"future-pet","breakMinutes":7}"#.utf8)
        let unknown = try JSONDecoder().decode(PomoSettings.self, from: unknownData)
        #expect(unknown.breakBuddy == .mochi)
        #expect(unknown.breakMinutes == 7)
    }

    @Test func buddySizeClampsLoadedValuesAndRoundTrips() throws {
        for (value, expected) in [(16, 64), (160, 160), (512, 192)] {
            let data = Data("{\"breakBuddy\":\"pip\",\"breakBuddySize\":\(value)}".utf8)
            let settings = try JSONDecoder().decode(PomoSettings.self, from: data)
            #expect(settings.breakBuddy == .pip)
            #expect(settings.breakBuddySize == Double(expected))
            #expect(try JSONDecoder().decode(PomoSettings.self, from: JSONEncoder().encode(settings)) == settings)
        }
    }

    @Test func tipsAdvanceAtTheBoundaryAndWrap() {
        #expect(BreakTips.message(elapsedSeconds: 0) == BreakTips.presets[0])
        #expect(BreakTips.message(elapsedSeconds: 11) == BreakTips.presets[0])
        #expect(BreakTips.message(elapsedSeconds: 12) == BreakTips.presets[1])
        #expect(BreakTips.message(elapsedSeconds: BreakTips.interval * BreakTips.presets.count) == BreakTips.presets[0])
        #expect(BreakTips.message(elapsedSeconds: -1) == BreakTips.presets[0])
    }

    @Test func companionFitsAtBothScreenEdgesAndOnAnotherDisplay() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 876),
            CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        ]
        for screen in screens {
            for size in [64.0, 128.0, 192.0] {
                for x in [screen.minX, screen.maxX - 322] {
                    let popover = CGRect(x: x, y: screen.maxY - 520, width: 322, height: 500)
                    let buddy = BreakBuddyPlacement.frame(nextTo: popover, visibleFrame: screen, buddySize: size)
                    #expect(screen.contains(buddy))
                    #expect(!buddy.intersects(popover))
                }
            }
        }
        let narrowScreen = CGRect(x: 0, y: 0, width: 400, height: 900)
        let popover = CGRect(x: 40, y: 400, width: 322, height: 480)
        let buddy = BreakBuddyPlacement.frame(nextTo: popover, visibleFrame: narrowScreen)
        #expect(narrowScreen.contains(buddy))
        #expect(buddy.maxY < popover.minY)
    }

    @Test @MainActor func selectionPersistsWithoutRestartingTheBreak() throws {
        let suite = "pomo.buddy.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date()
        let store = TimerStore(defaults: defaults, now: { now })
        store.start()
        now += 15
        store.pause()
        store.finishEarly()
        now += 20
        store.handleAppBecameActive()
        let remaining = store.remainingSeconds
        for (index, buddy) in BreakBuddy.allCases.enumerated() {
            store.settings.breakBuddy = buddy
            store.settings.breakBuddySize = Double(64 + index * 32)
            let restored = TimerStore(defaults: defaults)
            #expect(restored.settings.breakBuddy == buddy)
            #expect(restored.settings.breakBuddySize == store.settings.breakBuddySize)
            #expect(store.phase == .breakTime)
            #expect(store.isRunning)
            #expect(store.remainingSeconds == remaining)
            #expect(store.elapsedSeconds == 20)
        }
        store.skipBreak()
        #expect(store.settings.breakBuddy == .pip)
    }

    @Test @MainActor func breakPanelsJoinAllSpacesWithoutActivatingAnotherApp() throws {
        _ = NSApplication.shared
        let suite = "pomo.panel.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TimerStore(defaults: defaults)
        let timer = BreakWindowPanel(store: store, openMain: {})
        let buddy = BreakBuddyPanel(store: store)
        defer {
            timer.contentView = nil
            buddy.contentView = nil
            timer.close()
            buddy.close()
        }
        for panel in [timer, buddy] {
            #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
            #expect(panel.collectionBehavior.contains(.canJoinAllApplications))
            #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
            #expect(panel.styleMask.contains(.nonactivatingPanel))
            #expect(!panel.hidesOnDeactivate)
            #expect(panel.level == .floating)
            #expect(!panel.canBecomeMain)
        }
        #expect(timer.canBecomeKey)
        #expect(!buddy.canBecomeKey)
        #expect(buddy.ignoresMouseEvents)
    }
}
