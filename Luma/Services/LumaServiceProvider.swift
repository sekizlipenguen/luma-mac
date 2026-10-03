import AppKit
import LumaCore

/// Finder → Services → “Folder size in Luma”. Also handles `luma://folder-size` URLs.
final class LumaAppDelegate: NSObject, NSApplicationDelegate {
    let services = LumaServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            LumaServiceProvider.handleOpenURL(url)
        }
    }
}

final class LumaServiceProvider: NSObject {
    @objc func measureFolderSizeFromService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = Self.urls(from: pboard)
        guard !urls.isEmpty else {
            error.pointee = LumaL10n.string("No files were passed from Finder.") as NSString
            return
        }
        Task { @MainActor in
            FolderSizeSession.shared.enqueue(paths: urls.map(\.path))
        }
    }

    static func handleOpenURL(_ url: URL) {
        switch LumaDeepLink.parse(url) {
        case .folderSize(let paths):
            Task { @MainActor in
                FolderSizeSession.shared.enqueue(paths: paths)
            }
        case nil:
            break
        }
    }

    private static func urls(from pboard: NSPasteboard) -> [URL] {
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            return urls
        }
        return pboard.pasteboardItems?.compactMap { item in
            if let str = item.string(forType: .fileURL), let url = URL(string: str) {
                return url
            }
            return nil
        } ?? []
    }
}
