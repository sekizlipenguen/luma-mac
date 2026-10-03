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

    nonisolated static func allows(path: String, userID: UInt32, pid: Int32,
                                   currentUserID: UInt32, currentPID: Int32, ownApplicationPath: String?) -> Bool {
        guard pid > 1, pid != currentPID, userID == currentUserID, path != ownApplicationPath else { return false }
        return !["/System/Library/", "/usr/", "/bin/", "/sbin/"].contains(where: path.hasPrefix)
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
}
