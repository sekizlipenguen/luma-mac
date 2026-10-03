import Darwin
import XCTest
import LumaCore
@testable import LumaSystem

final class CPUProcessTests: XCTestCase {
    private func process(_ pid: Int32, parent: Int32 = 1, uid: UInt32 = 501, start: UInt64 = 1,
                         path: String = "/Applications/Browser.app/Contents/MacOS/Browser",
                         cpu: Double? = 0) -> CPUProcessInfo {
        CPUProcessInfo(pid: pid, parentPID: parent, userID: uid, startedAt: start,
                       name: "worker", executablePath: path, cpuPercent: cpu)
    }

    func testNestedHelpersAndChildCommandsContributeBeforeRanking() {
        let parent = process(10, cpu: 30)
        let helper = process(11, path: "/Applications/Browser.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper", cpu: 80)
        let command = process(12, parent: 10, path: "/usr/bin/tool", cpu: 15)
        let other = process(13, path: "/Applications/Other.app/Contents/MacOS/Other", cpu: 100)
        let groups = CPUProcessSampler.group([parent, helper, command, other])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.name, "Browser")
        XCTAssertEqual(groups.first?.cpuPercent, 125)
        XCTAssertEqual(Set(groups.first?.processes.map(\.pid) ?? []), [10, 11, 12])
    }

    func testNamesDifferentInstallationsAndUsersNeverMerge() {
        let groups = CPUProcessSampler.group([
            process(10, path: "/usr/bin/worker"), process(11, path: "/usr/bin/worker"),
            process(12), process(13, uid: 502),
            process(14, path: "/tmp/Browser.app/Contents/MacOS/Browser")
        ])
        XCTAssertEqual(groups.count, 5)
    }

    func testMissingParentsCyclesAndCrossUserParentRemainStandalone() {
        let groups = CPUProcessSampler.group([
            process(10, parent: 11, path: "/usr/bin/a"),
            process(11, parent: 10, path: "/usr/bin/b"),
            process(12, parent: 99, path: ""),
            process(13, parent: 14, uid: 502, path: "/usr/bin/c"), process(14)
        ])
        XCTAssertEqual(groups.count, 5)
        XCTAssertNil(groups.first(where: { $0.processes.first?.pid == 13 })?.applicationPath)
    }

    func testCPUUsesElapsedIntervalAndDoesNotClampMultipleCores() {
        let previous = CPUProcessSampler.Counter(process: process(10), cpuNanoseconds: 1_000_000_000, uptime: 10)
        let current = CPUProcessSampler.Counter(process: process(10), cpuNanoseconds: 4_000_000_000, uptime: 12)
        XCTAssertEqual(CPUProcessSampler.measured(current, previous: previous).cpuPercent, 150)
        XCTAssertNil(CPUProcessSampler.measured(current, previous: nil).cpuPercent)
        let reused = CPUProcessSampler.Counter(process: process(10, start: 2), cpuNanoseconds: 4_000_000_000, uptime: 12)
        XCTAssertNil(CPUProcessSampler.measured(reused, previous: previous).cpuPercent)
        let reset = CPUProcessSampler.Counter(process: process(10), cpuNanoseconds: 0, uptime: 12)
        XCTAssertNil(CPUProcessSampler.measured(reset, previous: previous).cpuPercent)
        XCTAssertNil(CPUProcessSampler.measured(previous, previous: previous).cpuPercent)
    }

    func testWarmupIsNotPresentedAsZeroCPU() {
        let group = CPUProcessSampler.group([process(10, cpu: 20), process(11, cpu: nil)]).first
        XCTAssertEqual(group?.cpuPercent, 20)
        XCTAssertTrue(group?.hasPendingSamples == true)
        XCTAssertNil(CPUProcessSampler.group([process(10, cpu: nil)]).first?.cpuPercent)
        XCTAssertEqual(CPUProcessSampler.group([process(10, cpu: 0)]).first?.cpuPercent, 0)
    }

    func testMachTimeConversionMatchesIndependentGetrusage() throws {
        let counter = try XCTUnwrap(CPUProcessSampler.readCounter(getpid()))
        var usage = rusage()
        XCTAssertEqual(getrusage(RUSAGE_SELF, &usage), 0)
        let seconds = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        XCTAssertEqual(counter.cpuNanoseconds / 1_000_000_000, seconds, accuracy: 0.05)
    }

    func testLaunchServicesMetadataGroupsCodeSigningCloneWithHelpers() {
        let root = CPUProcessInfo(pid: 10, parentPID: 1, userID: 501, startedAt: 1, name: "Browser",
                                 executablePath: "/private/var/code_sign_clone/Browser.app.bundle/Contents/MacOS/Browser",
                                 cpuPercent: 10, applicationPath: "/Applications/Browser.app")
        let helper = process(11, cpu: 20)
        let groups = CPUProcessSampler.group([root, helper])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.cpuPercent, 30)
    }

    func testQuitPolicyProtectsSystemSelfAndOtherUsers() {
        func allowed(_ path: String, uid: UInt32 = 501, pid: Int32 = 10) -> Bool {
            CPUApplicationControl.allows(path: path, userID: uid, pid: pid,
                                        currentUserID: 501, currentPID: 20, ownApplicationPath: "/Applications/Luma.app")
        }
        XCTAssertTrue(allowed("/Applications/Browser.app"))
        XCTAssertTrue(allowed("/System/Applications/Calculator.app"))
        XCTAssertFalse(allowed("/System/Library/CoreServices/Finder.app"))
        XCTAssertFalse(allowed("/usr/Background.app"))
        XCTAssertFalse(allowed("/Applications/Luma.app"))
        XCTAssertFalse(allowed("/Applications/Browser.app", uid: 0))
        XCTAssertFalse(allowed("/Applications/Browser.app", pid: 20))
        XCTAssertFalse(allowed("/Applications/Browser.app", pid: 1))
    }

    func testSamplerSeesItsOwnIdentityAndRejectsStaleIdentity() async throws {
        let sampler = CPUProcessSampler()
        let first = await sampler.sample()
        let own = try XCTUnwrap(first.flatMap(\.processes).first { $0.pid == ProcessInfo.processInfo.processIdentifier })
        XCTAssertTrue(CPUProcessSampler.isCurrentProcess(own))
        let stale = CPUProcessInfo(pid: own.pid, parentPID: own.parentPID, userID: own.userID,
                                   startedAt: own.startedAt + 1, name: own.name,
                                   executablePath: own.executablePath, cpuPercent: nil)
        XCTAssertFalse(CPUProcessSampler.isCurrentProcess(stale))
        try await Task.sleep(for: .milliseconds(400))
        let second = await sampler.sample()
        let measured = try XCTUnwrap(second.flatMap(\.processes).first { $0.id == own.id })
        XCTAssertNotNil(measured.cpuPercent)
        XCTAssertTrue(measured.cpuPercent?.isFinite == true)
    }
}
