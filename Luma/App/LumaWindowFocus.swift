import AppKit

/// Routes “Open Luma” from the status item even when the last SwiftUI window was closed.
@MainActor
final class LumaWindowRouter {
    static let shared = LumaWindowRouter()

    /// Captured from the WindowGroup so `openWindow(id:)` stays available after the last window closes.
    var openMainWindow: (() -> Void)?
    var openFolderSizeWindow: (() -> Void)?

    func reveal() {
        // Prefer creating/showing via SwiftUI first when we have no main window.
        if !hasMainWindow {
            openMainWindow?()
        }
        LumaWindowFocus.bringMainToFront { [weak self] in
            self?.openMainWindow?()
        }
    }

    private var hasMainWindow: Bool {
        NSApp.windows.contains { window in
            window.canBecomeKey
                && window.frame.width >= 280
                && window.frame.height >= 180
                && !window.className.contains("StatusBar")
        }
    }
}

/// Brings Luma’s main window forward from the status-item menu.
/// Menu dismissal often steals focus, so we activate on the next run-loop turn too.
@MainActor
enum LumaWindowFocus {
    static func bringMainToFront(openIfNeeded: (() -> Void)? = nil) {
        NSApp.setActivationPolicy(.regular)

        let mains = mainWindows()
        if mains.isEmpty {
            openIfNeeded?()
        } else {
            for window in mains {
                raise(window)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            var windows = mainWindows()
            if windows.isEmpty {
                openIfNeeded?()
                windows = mainWindows()
            }
            for window in windows {
                raise(window)
            }
        }

        // Status-item menus release key focus after the item action returns.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            for window in mainWindows() {
                raise(window)
            }
        }
    }

    private static func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            guard window.canBecomeKey else { return false }
            // Skip status-item / tooltip / zero-size chrome.
            guard window.frame.width >= 280, window.frame.height >= 180 else { return false }
            if window.className.contains("StatusBar") { return false }
            if window.className.contains("NSPopupMenu") { return false }
            return true
        }
        .sorted { lhs, rhs in
            let la = lhs.frame.width * lhs.frame.height
            let ra = rhs.frame.width * rhs.frame.height
            return la > ra
        }
    }

    private static func raise(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
