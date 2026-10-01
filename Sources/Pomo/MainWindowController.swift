import AppKit
import Combine

/// Only explicit open requests may present the main scene. Timer transitions don't use this controller.
@MainActor
final class MainWindowController {
    private weak var window: NSWindow?
    private var openScene: (() -> Void)?
    private var closeSubscription: AnyCancellable?

    func register(_ window: NSWindow, openScene: @escaping () -> Void) {
        self.openScene = openScene
        guard self.window !== window else { return }
        self.window = window
        closeSubscription = NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: window)
            .sink { [weak self] _ in
                // Let SwiftUI reopen a closed scene, even if AppKit still retains its old window.
                self?.window = nil
                self?.closeSubscription = nil
            }
    }

    func open() {
        guard let window else {
            openScene?()
            return
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }
}
