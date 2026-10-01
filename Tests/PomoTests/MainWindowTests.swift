import AppKit
import Foundation
import Testing
@testable import Pomo

@MainActor
struct MainWindowTests {
    private final class WindowSpy: NSWindow {
        var presentationCount = 0
        var minimizationCount = 0
        var restorationCount = 0
        var hiddenCount = 0
        var minimized = false

        init() {
            super.init(contentRect: CGRect(x: 0, y: 0, width: 820, height: 620),
                       styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            isReleasedWhenClosed = false
        }

        override var isMiniaturized: Bool { minimized }
        override func makeKeyAndOrderFront(_ sender: Any?) { presentationCount += 1 }
        override func miniaturize(_ sender: Any?) {
            minimizationCount += 1
            minimized = true
        }
        override func deminiaturize(_ sender: Any?) {
            restorationCount += 1
            minimized = false
        }
        override func orderOut(_ sender: Any?) { hiddenCount += 1 }
    }

    @Test func explicitOpenTargetsTheMainWindowAndRestoresManualMinimization() {
        _ = NSApplication.shared
        let controller = MainWindowController()
        let main = WindowSpy()
        let settings = WindowSpy()
        defer { main.close(); settings.close() }
        var sceneRequests = 0
        controller.register(main) { sceneRequests += 1 }
        #expect(main.presentationCount == 0)
        #expect(main.hiddenCount == 0)

        main.minimized = true
        controller.open()
        #expect(main.restorationCount == 1)
        #expect(main.presentationCount == 1)
        #expect(!main.isMiniaturized)
        controller.open()
        #expect(main.presentationCount == 2)
        #expect(main.restorationCount == 1)
        #expect(settings.presentationCount == 0)
        #expect(sceneRequests == 0)
    }

    @Test func closedMainWindowReopensItsSwiftUISceneOnlyOnRequest() {
        _ = NSApplication.shared
        let controller = MainWindowController()
        let oldMain = WindowSpy()
        let newMain = WindowSpy()
        defer { oldMain.close(); newMain.close() }
        var sceneRequests = 0
        controller.register(oldMain) { sceneRequests += 1 }
        oldMain.close()
        #expect(sceneRequests == 0)
        controller.open()
        #expect(sceneRequests == 1)
        #expect(oldMain.presentationCount == 0)
        controller.register(newMain) { sceneRequests += 1 }
        controller.open()
        #expect(sceneRequests == 1)
        #expect(newMain.presentationCount == 1)
    }

    @Test func focusPauseResumeAndBreakLeaveClosedMainWindowAlone() throws {
        _ = NSApplication.shared
        let suite = "pomo.window.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date()
        let store = TimerStore(defaults: defaults, now: { date })
        let delegate = AppDelegate(store: store)
        let main = WindowSpy()
        defer { main.close() }
        var sceneRequests = 0
        delegate.mainWindowController.register(main) { sceneRequests += 1 }
        main.close()
        let hiddenAtClose = main.hiddenCount

        for _ in 0..<2 {
            store.start()
            date += 10
            store.pause()
            store.start()
            date += 10
            store.pause()
            store.finishEarly()
            #expect(store.phase == .breakTime)
            // Exercise the focus callback branch that shows saved break notes too.
            store.checkpointDraft = "Resume the same task"
            store.addCheckpoint()
            store.skipBreak()
            #expect(store.phase == .focus)
        }
        #expect(main.presentationCount == 0)
        #expect(main.minimizationCount == 0)
        #expect(main.restorationCount == 0)
        #expect(main.hiddenCount == hiddenAtClose)
        #expect(sceneRequests == 0)
        #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
        delegate.mainWindowController.open()
        #expect(sceneRequests == 1)
    }
}
