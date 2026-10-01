import AppKit
import Combine
import SwiftUI

@main
struct PomoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(store: appDelegate.store)
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        Settings {
            SettingsView(store: appDelegate.store)
                .frame(width: 620, height: 540)
        }
    }

}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TimerStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var breakWindowPanel: BreakWindowPanel?
    private var breakBuddyPanel: BreakBuddyPanel?
    private var cancellables = Set<AnyCancellable>()
    private var shouldHideInitialWindow = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.imagePosition = .imageLeft
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem = item

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 322, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(store: store, openMain: { [weak self] in self?.openMainWindow() })
        )

        store.onBreakStarted = { [weak self] in
            self?.showBreakWindow()
        }
        store.onBreakEnded = { [weak self] in
            self?.hideBreakWindows()
            self?.popover.behavior = .transient
            self?.showPopover()
        }
        store.onFocusStarted = { [weak self] in
            self?.hideBreakWindows()
            self?.popover.behavior = .transient
            if self?.store.breakNotesForNextFocus.isEmpty == true {
                self?.popover.performClose(nil)
            } else {
                self?.showPopover()
            }
            self?.minimizeMainWindowForFocus()
        }

        Publishers.CombineLatest3(store.$remainingSeconds, store.$phase, store.$isRunning)
            .sink { [weak self] remaining, phase, running in
                self?.updateStatusItem(remaining: remaining, phase: phase, running: running)
            }
            .store(in: &cancellables)
        updateStatusItem(remaining: store.remainingSeconds, phase: store.phase, running: store.isRunning)
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] notification in
                    guard let self, let window = notification.object as? NSWindow,
                          window === self.breakWindowPanel else { return }
                    self.showBreakBuddy()
                }
                .store(in: &cancellables)
        }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard self?.store.phase == .breakTime else { return }
                self?.showBreakWindow(makeKey: false)
            }
            .store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.store.phase == .breakTime else { return }
                self?.showBreakWindow(makeKey: false, reposition: false)
            }
            .store(in: &cancellables)
        store.$settings.dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showBreakBuddy() }
            .store(in: &cancellables)
        DispatchQueue.main.async { [weak self] in self?.hideInitialWindow() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        hideInitialWindow()
    }

    @objc private func togglePopover() {
        if store.phase == .breakTime {
            showBreakWindow()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard store.phase == .focus else {
            showBreakWindow()
            return
        }
        guard let button = statusItem?.button else { return }
        popover.behavior = .transient
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showBreakWindow(makeKey: Bool = true, reposition: Bool = true) {
        guard store.phase == .breakTime,
              let button = statusItem?.button, let statusWindow = button.window,
              let screen = statusWindow.screen ?? NSScreen.main else { return }
        popover.performClose(nil)
        let isNewWindow = breakWindowPanel == nil
        if isNewWindow {
            breakWindowPanel = BreakWindowPanel(store: store, openMain: { [weak self] in self?.openMainWindow() })
        }
        guard let panel = breakWindowPanel else { return }
        if reposition || isNewWindow {
            let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = screen.visibleFrame
            let height = min(visible.height, max(320, panel.contentView?.fittingSize.height ?? 400))
            let frame = CGRect(
                x: min(max(anchor.maxX - 322, visible.minX), visible.maxX - 322),
                y: min(max(anchor.minY - height - 8, visible.minY), visible.maxY - height),
                width: 322, height: height
            )
            panel.setFrame(frame, display: true)
        }
        panel.orderFrontRegardless()
        if makeKey { panel.makeKey() }
        showBreakBuddy()
    }

    private func showBreakBuddy() {
        guard store.phase == .breakTime,
              let window = breakWindowPanel, window.isVisible,
              let screen = window.screen else {
            hideBreakBuddy()
            return
        }
        if breakBuddyPanel == nil { breakBuddyPanel = BreakBuddyPanel(store: store) }
        breakBuddyPanel?.setFrame(BreakBuddyPlacement.frame(nextTo: window.frame, visibleFrame: screen.visibleFrame,
                                                           buddySize: store.settings.breakBuddySize), display: true)
        breakBuddyPanel?.orderFrontRegardless()
    }

    private func hideBreakBuddy() {
        // Remove the hosting view while hidden so its animation schedule stops between breaks.
        breakBuddyPanel?.contentView = nil
        breakBuddyPanel?.close()
        breakBuddyPanel = nil
    }

    private func hideBreakWindows() {
        hideBreakBuddy()
        breakWindowPanel?.contentView = nil
        breakWindowPanel?.close()
        breakWindowPanel = nil
    }

    private func updateStatusItem(remaining: Int, phase: TimerPhase, running: Bool) {
        guard let button = statusItem?.button else { return }
        button.image = nil
        button.title = "🍅 \(remaining.clockString)"
        button.toolTip = phase == .focus
            ? (running ? "Pomo focus timer — running" : "Pomo focus timer — paused")
            : "Pomo break timer — running"
    }

    private func openMainWindow() {
        shouldHideInitialWindow = false
        if store.phase != .breakTime && store.breakNotesForNextFocus.isEmpty { popover.performClose(nil) }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0 !== popover.contentViewController?.view.window && $0 !== breakWindowPanel }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func hideInitialWindow() {
        guard shouldHideInitialWindow else { return }
        let mainWindows = NSApp.windows.filter { $0.canBecomeKey && $0 !== popover.contentViewController?.view.window && $0 !== breakWindowPanel }
        guard !mainWindows.isEmpty else { return }
        shouldHideInitialWindow = false
        for window in mainWindows {
            window.orderOut(nil)
        }
    }

    private func minimizeMainWindowForFocus() {
        for window in NSApp.windows where window.canBecomeKey && window !== popover.contentViewController?.view.window && window !== breakWindowPanel {
            window.miniaturize(nil)
        }
    }
}

struct RootView: View {
    @ObservedObject var store: TimerStore
    @State private var selectedPage: AppPage? = .timer

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TimerPhase.focus.color.gradient)
                        Image(systemName: "circle.dotted.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pomo").font(.headline)
                        Text("make time visible").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 18)
                .padding(.bottom, 14)

                List(AppPage.allCases, selection: $selectedPage) { page in
                    Label(page.title, systemImage: page.symbol).tag(page)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TODAY").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        Spacer()
                        Text(store.focusedSecondsToday.compactDuration).font(.caption.monospacedDigit())
                    }
                    ProgressView(value: min(1, Double(store.focusedSecondsToday) / Double(max(1, store.settings.dailyGoalMinutes * 60))))
                        .tint(TimerPhase.focus.color)
                    Text("\(store.completedFocusCountToday) completed sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
                .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 235)
        } detail: {
            switch selectedPage ?? .timer {
            case .timer: TimerView(store: store)
            case .checkpoints: CheckpointsView(store: store)
            case .statistics: StatisticsView(store: store)
            case .timeline: DailyTimelineView(store: store)
            case .settings: SettingsView(store: store)
            }
        }
        .tint(store.currentTint)
    }
}
