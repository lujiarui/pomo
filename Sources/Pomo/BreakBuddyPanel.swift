import AppKit
import SwiftUI

enum BreakBuddyPlacement {
    static func size(for buddySize: Double = 128) -> CGSize {
        CGSize(width: max(184, buddySize + 20), height: buddySize + 120)
    }

    static func frame(nextTo window: CGRect, visibleFrame screen: CGRect, buddySize: Double = 128) -> CGRect {
        let gap: CGFloat = 10
        let panelSize = size(for: buddySize)
        let width = min(panelSize.width, screen.width)
        let height = min(panelSize.height, screen.height)
        let left = window.minX - width - gap
        let right = window.maxX + gap
        let x: CGFloat
        let y: CGFloat
        if left >= screen.minX {
            x = left
            y = window.maxY - height - 30
        } else if right + width <= screen.maxX {
            x = right
            y = window.maxY - height - 30
        } else {
            x = window.midX - width / 2
            y = window.minY - height - gap
        }
        return CGRect(
            x: min(max(x, screen.minX), screen.maxX - width),
            y: min(max(y, screen.minY), screen.maxY - height),
            width: width, height: height
        )
    }
}

@MainActor
final class BreakBuddyPanel: NSPanel {
    init(store: TimerStore) {
        super.init(contentRect: CGRect(origin: .zero, size: BreakBuddyPlacement.size(for: store.settings.breakBuddySize)),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        contentView = NSHostingView(rootView: FloatingBreakBuddyView(store: store))
        setAccessibilityLabel("Break buddy")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A regular AppKit panel can join every Space; NSPopover's window is tied to its anchor's Space.
@MainActor
final class BreakWindowPanel: NSPanel {
    init(store: TimerStore, openMain: @escaping () -> Void) {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 322, height: 400),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        contentView = NSHostingView(rootView: MenuBarView(store: store, openMain: openMain)
            .clipShape(RoundedRectangle(cornerRadius: 15)))
        setAccessibilityLabel("Pomo break timer")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
