import Foundation
import LumaCore
import os

public enum LumaLog {
    public static let general = Logger(subsystem: "dev.luma.app", category: "general")
    public static let metrics = Logger(subsystem: "dev.luma.app", category: "metrics")
    public static let cleanup = Logger(subsystem: "dev.luma.app", category: "cleanup")
    public static let storage = Logger(subsystem: "dev.luma.app", category: "storage")
}
