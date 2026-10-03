import Foundation

/// URL scheme `luma:` — used by Finder Sync / Services to talk to the running app.
public enum LumaDeepLink: Equatable, Sendable {
    case folderSize(paths: [String])

    public static let scheme = "luma"

    public static func parse(_ url: URL) -> LumaDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = (components.scheme ?? url.scheme)?.lowercased()
        guard scheme == Self.scheme else { return nil }

        let host = (components.host ?? "").lowercased()
        let pathHost = url.host?.lowercased()
        let isFolderSize = host == "folder-size"
            || pathHost == "folder-size"
            || url.path.lowercased().contains("folder-size")
        guard isFolderSize else { return nil }

        let paths = (components.queryItems ?? [])
            .filter { $0.name == "path" }
            .compactMap(\.value)
            .map { $0.removingPercentEncoding ?? $0 }
            .filter { !$0.isEmpty }
        guard !paths.isEmpty else { return nil }
        return .folderSize(paths: paths)
    }

    public static func folderSizeURL(paths: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "folder-size"
        components.queryItems = paths
            .filter { !$0.isEmpty }
            .map { URLQueryItem(name: "path", value: $0) }
        return components.url
    }
}
