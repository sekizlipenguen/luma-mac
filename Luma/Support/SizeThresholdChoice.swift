import Foundation
import LumaCore
import LumaStorage
import LumaSupport

enum LargeFileThresholdChoice: String, CaseIterable, Identifiable {
    case mb100
    case mb500
    case gb1
    case gb5
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mb100: LargeFileThreshold.mb100.title
        case .mb500: LargeFileThreshold.mb500.title
        case .gb1: LargeFileThreshold.gb1.title
        case .gb5: LargeFileThreshold.gb5.title
        case .custom: LumaL10n.string("Custom")
        }
    }

    var preset: LargeFileThreshold? {
        switch self {
        case .mb100: .mb100
        case .mb500: .mb500
        case .gb1: .gb1
        case .gb5: .gb5
        case .custom: nil
        }
    }
}

enum DuplicateMinSizeChoice: String, CaseIterable, Identifiable {
    case kb100
    case mb1
    case mb10
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kb100: DuplicateMinSize.kb100.title
        case .mb1: DuplicateMinSize.mb1.title
        case .mb10: DuplicateMinSize.mb10.title
        case .custom: LumaL10n.string("Custom")
        }
    }

    var preset: DuplicateMinSize? {
        switch self {
        case .kb100: .kb100
        case .mb1: .mb1
        case .mb10: .mb10
        case .custom: nil
        }
    }
}
