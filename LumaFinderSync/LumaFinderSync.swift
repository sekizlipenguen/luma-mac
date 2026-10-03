import AppKit
import FinderSync

/// Finder contextual menu + toolbar. Measuring happens in the main Luma app (not inside Finder).
final class LumaFinderSync: FIFinderSync {
    override init() {
        super.init()
        var roots: Set<URL> = [
            FileManager.default.homeDirectoryForCurrentUser,
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Volumes"),
            URL(fileURLWithPath: "/Users")
        ]
        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            roots.formUnion(volumes)
        }
        FIFinderSyncController.default().directoryURLs = roots
    }

    override var toolbarItemName: String { "Luma" }

    override var toolbarItemToolTip: String {
        "Show selected folder size in Luma"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Luma")
            ?? NSImage(named: NSImage.folderName)
            ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Folder size in Luma",
            action: #selector(showFolderSize(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc func showFolderSize(_ sender: AnyObject?) {
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        let targeted = FIFinderSyncController.default().targetedURL().map { [$0] } ?? []
        let urls = selected.isEmpty ? targeted : selected
        guard !urls.isEmpty else { return }

        var components = URLComponents()
        components.scheme = "luma"
        components.host = "folder-size"
        components.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
