import SwiftUI

/// Shared list / card layout preference for Storage, Network, Large Files & Duplicates.
enum ListCardLayout: String, CaseIterable, Identifiable {
    case list
    case cards

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .list: "List"
        case .cards: "Cards"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .cards: "square.grid.2x2"
        }
    }
}

enum ListCardLayoutKeys {
    static let storage = "luma.layout.storage"
    static let networkApps = "luma.layout.network.apps"
    static let networkConnections = "luma.layout.network.connections"
    static let networkInterfaces = "luma.layout.network.interfaces"
    static let largeFiles = "luma.layout.largeFiles"
    static let duplicates = "luma.layout.duplicates"
}
