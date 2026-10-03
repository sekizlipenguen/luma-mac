import AppKit
import LumaCore
import LumaSupport
import LumaSystem

/// AppKit status item — SwiftUI `MenuBarExtra` was pegging the main thread
/// (`AppMenuBarExtrasController.updateMenuBarExtras` in a tight loop, 2GB+ RSS).
@MainActor
final class LumaStatusItemController: NSObject {
    private let metrics: SystemMetricsService
    private var statusItem: NSStatusItem?
    private var refreshTask: Task<Void, Never>?

    init(metrics: SystemMetricsService) {
        self.metrics = metrics
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            install()
        } else {
            uninstall()
        }
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Luma")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Luma", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let cpu = NSMenuItem(title: "CPU —", action: nil, keyEquivalent: "")
        cpu.tag = 1
        menu.addItem(cpu)
        let mem = NSMenuItem(title: "Memory —", action: nil, keyEquivalent: "")
        mem.tag = 2
        menu.addItem(mem)
        menu.addItem(.separator())
        let open = NSMenuItem(title: LumaL10n.string("Open Luma"), action: #selector(openLuma), keyEquivalent: "o")
        open.target = self
        menu.addItem(open)
        let quit = NSMenuItem(title: LumaL10n.string("Quit Luma"), action: #selector(quitLuma), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        startRefreshing()
    }

    private func uninstall() {
        refreshTask?.cancel()
        refreshTask = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshLabels()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func refreshLabels() async {
        guard let menu = statusItem?.menu else { return }
        do {
            let snap = try await metrics.quickSnapshot()
            let cpu = PercentFormatters.string(snap.cpu.overallUsage)
            let mem = ByteFormatters.string(for: snap.memory.usedBytes)
            menu.item(withTag: 1)?.title = LumaL10n.format("CPU %@", cpu)
            menu.item(withTag: 2)?.title = LumaL10n.format("Memory %@", mem)
        } catch {
            // Keep previous labels.
        }
    }

    @objc private func openLuma() {
        NotificationCenter.default.post(name: .lumaOpenMainWindow, object: nil)
        LumaWindowRouter.shared.reveal()
    }

    @objc private func quitLuma() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let lumaOpenMainWindow = Notification.Name("dev.luma.app.openMainWindow")
}
