import AppKit
import Darwin
import LumaCore

/// Safety-Model: no root helper. Quit only regular, owned apps through AppKit.
@MainActor
public enum CPUApplicationControl {
    public enum QuitResult { case requested, unavailable, declined }

    public static func canQuit(_ group: CPUProcessGroup) -> Bool {
        !candidates(group).isEmpty
    }

    public static func quit(_ group: CPUProcessGroup) -> QuitResult {
        // Recheck identity at confirmation time: a vanished/reused PID is never a target.
        let applications = candidates(group).filter { app in
            guard let process = group.processes.first(where: { $0.pid == app.processIdentifier }) else { return false }
            return CPUProcessSampler.isCurrentProcess(process)
        }
        guard !applications.isEmpty else { return .unavailable }
        var allAccepted = true
        for app in applications {
            if !app.terminate() { allAccepted = false }
        }
        return allAccepted ? .requested : .declined
    }

    public static func backgroundApps() -> [BackgroundApp] {
        listed(
            NSWorkspace.shared.runningApplications.compactMap(probe),
            currentUserID: geteuid(),
            currentPID: getpid(),
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            ownApplicationPath: Bundle.main.bundleURL.resolvingSymlinksInPath().path
        )
    }

    public static func quit(_ app: BackgroundApp) -> QuitResult {
        let applications = backgroundCandidates(app)
        guard !applications.isEmpty else { return .unavailable }
        var allAccepted = true
        for running in applications {
            if !running.terminate() { allAccepted = false }
        }
        return allAccepted ? .requested : .declined
    }

    public static func quitAll(_ apps: [BackgroundApp]) -> BackgroundAppQuitAllResult {
        var requested = 0
        var declined = 0
        var unavailable = 0
        for app in apps {
            switch quit(app) {
            case .requested: requested += 1
            case .declined: declined += 1
            case .unavailable: unavailable += 1
            }
        }
        return BackgroundAppQuitAllResult(requested: requested, declined: declined, unavailable: unavailable)
    }

    nonisolated static func allows(path: String, userID: UInt32, pid: Int32,
                                   currentUserID: UInt32, currentPID: Int32, ownApplicationPath: String?) -> Bool {
        guard pid > 1, pid != currentPID, userID == currentUserID, path != ownApplicationPath else { return false }
        return !["/System/Library/", "/usr/", "/bin/", "/sbin/"].contains(where: path.hasPrefix)
    }

    /// Regular, owned, still-running apps only. Accessory agents and host services stay hidden.
    nonisolated static func listed(
        _ probes: [BackgroundAppProbe],
        currentUserID: UInt32,
        currentPID: Int32,
        ownBundleIdentifier: String?,
        ownApplicationPath: String?
    ) -> [BackgroundApp] {
        probes.compactMap { probe in
            guard probe.isRegular, !probe.isTerminated,
                  probe.bundleIdentifier != ownBundleIdentifier,
                  allows(path: probe.bundlePath, userID: probe.userID, pid: probe.pid,
                         currentUserID: currentUserID, currentPID: currentPID,
                         ownApplicationPath: ownApplicationPath)
            else { return nil }
            return BackgroundApp(
                identifier: "app:\(probe.pid):\(probe.bundlePath)",
                name: probe.name,
                kind: .app,
                bundleIdentifier: probe.bundleIdentifier,
                iconPath: probe.bundlePath,
                detail: "PID \(probe.pid)",
                pid: probe.pid,
                isRunning: true,
                stopJobs: []
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func candidates(_ group: CPUProcessGroup) -> [NSRunningApplication] {
        guard let path = group.applicationPath else { return [] }
        let ownPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  app.bundleURL?.resolvingSymlinksInPath().path == path,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let process = group.processes.first(where: { $0.pid == app.processIdentifier }) else { return false }
            return allows(path: path, userID: process.userID, pid: process.pid,
                          currentUserID: geteuid(), currentPID: getpid(), ownApplicationPath: ownPath)
        }
    }

    private static func backgroundCandidates(_ app: BackgroundApp) -> [NSRunningApplication] {
        let ownPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        guard let path = app.iconPath, let pid = app.pid else { return [] }
        return NSWorkspace.shared.runningApplications.filter { running in
            guard running.processIdentifier == pid, !running.isTerminated,
                  running.activationPolicy == .regular,
                  running.bundleIdentifier != Bundle.main.bundleIdentifier,
                  running.bundleURL?.resolvingSymlinksInPath().path == path
            else { return false }
            return allows(path: path, userID: geteuid(), pid: running.processIdentifier,
                          currentUserID: geteuid(), currentPID: getpid(), ownApplicationPath: ownPath)
        }
    }

    private static func probe(_ app: NSRunningApplication) -> BackgroundAppProbe? {
        guard let path = app.bundleURL?.resolvingSymlinksInPath().path, path.hasSuffix(".app") else { return nil }
        let name = app.localizedName
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return BackgroundAppProbe(
            pid: app.processIdentifier,
            name: name,
            bundleIdentifier: app.bundleIdentifier,
            bundlePath: path,
            isHidden: app.isHidden,
            isTerminated: app.isTerminated,
            isRegular: app.activationPolicy == .regular,
            userID: geteuid()
        )
    }
}

struct BackgroundAppProbe: Sendable, Equatable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let bundlePath: String
    let isHidden: Bool
    let isTerminated: Bool
    let isRegular: Bool
    let userID: UInt32
}
