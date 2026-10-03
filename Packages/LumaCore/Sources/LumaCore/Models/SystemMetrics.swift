import Foundation

/// CPU utilization derived from Mach `host_processor_info` tick deltas.
public struct CPUMetrics: Sendable, Equatable {
    public var overallUsage: Double
    public var perCoreUsage: [Double]
    public var loadAverage: (Double, Double, Double)
    public var sampledAt: Date

    public init(
        overallUsage: Double,
        perCoreUsage: [Double],
        loadAverage: (Double, Double, Double),
        sampledAt: Date = .now
    ) {
        self.overallUsage = overallUsage
        self.perCoreUsage = perCoreUsage
        self.loadAverage = loadAverage
        self.sampledAt = sampledAt
    }

    public static func == (lhs: CPUMetrics, rhs: CPUMetrics) -> Bool {
        lhs.overallUsage == rhs.overallUsage
            && lhs.perCoreUsage == rhs.perCoreUsage
            && lhs.loadAverage.0 == rhs.loadAverage.0
            && lhs.loadAverage.1 == rhs.loadAverage.1
            && lhs.loadAverage.2 == rhs.loadAverage.2
    }
}

/// How memory pressure was obtained — never invent values.
public enum MemoryPressureSource: String, Sendable, Equatable {
    case dispatchSource
    case estimatedFromVMStats
    case unavailable
}

public enum MemoryPressureLevel: String, Sendable, Equatable {
    case normal
    case warning
    case critical
    case unknown
}

/// Virtual memory counters from `host_statistics64` / `HOST_VM_INFO64`.
public struct MemoryMetrics: Sendable, Equatable {
    public var totalBytes: UInt64
    public var activeBytes: UInt64
    public var inactiveBytes: UInt64
    public var wiredBytes: UInt64
    public var compressedBytes: UInt64
    public var freeBytes: UInt64
    public var purgeableBytes: UInt64
    public var speculativeBytes: UInt64
    public var swapUsedBytes: UInt64
    public var swapTotalBytes: UInt64
    public var pressure: MemoryPressureLevel
    public var pressureSource: MemoryPressureSource
    public var sampledAt: Date

    public init(
        totalBytes: UInt64,
        activeBytes: UInt64,
        inactiveBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        freeBytes: UInt64,
        purgeableBytes: UInt64,
        speculativeBytes: UInt64,
        swapUsedBytes: UInt64,
        swapTotalBytes: UInt64,
        pressure: MemoryPressureLevel,
        pressureSource: MemoryPressureSource,
        sampledAt: Date = .now
    ) {
        self.totalBytes = totalBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.freeBytes = freeBytes
        self.purgeableBytes = purgeableBytes
        self.speculativeBytes = speculativeBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
        self.pressure = pressure
        self.pressureSource = pressureSource
        self.sampledAt = sampledAt
    }

    /// App-used style footprint: active + wired + compressed (matches Activity Monitor “Memory Used” intent).
    public var usedBytes: UInt64 {
        activeBytes + wiredBytes + compressedBytes
    }

    public var cachedLikeBytes: UInt64 {
        inactiveBytes + purgeableBytes
    }
}

public struct DiskVolumeMetrics: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var totalBytes: UInt64
    public var freeBytes: UInt64
    public var fileSystem: String

    public var usedBytes: UInt64 {
        totalBytes >= freeBytes ? totalBytes - freeBytes : 0
    }

    public init(path: String, name: String, totalBytes: UInt64, freeBytes: UInt64, fileSystem: String) {
        self.path = path
        self.name = name
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.fileSystem = fileSystem
    }
}

public struct BatteryMetrics: Sendable, Equatable {
    public var isPresent: Bool
    public var isCharging: Bool
    public var currentCapacityPercent: Int?
    public var designCapacityMilliAmpHours: Int?
    public var maxCapacityMilliAmpHours: Int?
    public var cycleCount: Int?
    public var timeRemainingMinutes: Int?
    public var healthPercent: Int?
    public var sampledAt: Date

    public init(
        isPresent: Bool,
        isCharging: Bool = false,
        currentCapacityPercent: Int? = nil,
        designCapacityMilliAmpHours: Int? = nil,
        maxCapacityMilliAmpHours: Int? = nil,
        cycleCount: Int? = nil,
        timeRemainingMinutes: Int? = nil,
        healthPercent: Int? = nil,
        sampledAt: Date = .now
    ) {
        self.isPresent = isPresent
        self.isCharging = isCharging
        self.currentCapacityPercent = currentCapacityPercent
        self.designCapacityMilliAmpHours = designCapacityMilliAmpHours
        self.maxCapacityMilliAmpHours = maxCapacityMilliAmpHours
        self.cycleCount = cycleCount
        self.timeRemainingMinutes = timeRemainingMinutes
        self.healthPercent = healthPercent
        self.sampledAt = sampledAt
    }

    public static let desktopNoBattery = BatteryMetrics(isPresent: false)
}

public struct NetworkMetrics: Sendable, Equatable {
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64
    public var sampledAt: Date

    public init(
        bytesInPerSecond: Double,
        bytesOutPerSecond: Double,
        totalBytesIn: UInt64,
        totalBytesOut: UInt64,
        sampledAt: Date = .now
    ) {
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.sampledAt = sampledAt
    }
}

/// One network interface with addresses and traffic (from `getifaddrs`).
public struct NetworkInterfaceInfo: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var kindLabel: String
    public var ipv4Addresses: [String]
    public var ipv6Addresses: [String]
    public var macAddress: String?
    public var isUp: Bool
    public var isRunning: Bool
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double

    public init(
        name: String,
        kindLabel: String,
        ipv4Addresses: [String],
        ipv6Addresses: [String],
        macAddress: String?,
        isUp: Bool,
        isRunning: Bool,
        bytesIn: UInt64,
        bytesOut: UInt64,
        bytesInPerSecond: Double,
        bytesOutPerSecond: Double
    ) {
        self.name = name
        self.kindLabel = kindLabel
        self.ipv4Addresses = ipv4Addresses
        self.ipv6Addresses = ipv6Addresses
        self.macAddress = macAddress
        self.isUp = isUp
        self.isRunning = isRunning
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
    }
}

public enum NetworkPathStatus: String, Sendable, Equatable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown
}

public enum NetworkSocketProtocol: String, Sendable, Equatable {
    case tcp
    case udp
}

/// Live socket from `proc_pidfdinfo` / `PROC_PIDFDSOCKETINFO` (who ↔ where).
public struct NetworkConnection: Sendable, Equatable, Identifiable {
    public var id: String {
        "\(pid)-\(protocolKind.rawValue)-\(localAddress):\(localPort)-\(remoteAddress):\(remotePort)"
    }

    public var pid: Int32
    public var processName: String
    public var protocolKind: NetworkSocketProtocol
    public var localAddress: String
    public var localPort: Int
    public var remoteAddress: String
    public var remotePort: Int
    public var tcpState: String?

    public init(
        pid: Int32,
        processName: String,
        protocolKind: NetworkSocketProtocol,
        localAddress: String,
        localPort: Int,
        remoteAddress: String,
        remotePort: Int,
        tcpState: String?
    ) {
        self.pid = pid
        self.processName = processName
        self.protocolKind = protocolKind
        self.localAddress = localAddress
        self.localPort = localPort
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.tcpState = tcpState
    }

    public var remoteEndpoint: String { "\(remoteAddress):\(remotePort)" }
    public var localEndpoint: String { "\(localAddress):\(localPort)" }
}

/// App rolled up by open remote connections (not byte counters — those need private APIs).
public struct NetworkAppSummary: Sendable, Equatable, Identifiable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var processName: String
    public var connectionCount: Int
    public var remoteEndpoints: [String]

    public init(pid: Int32, processName: String, connectionCount: Int, remoteEndpoints: [String]) {
        self.pid = pid
        self.processName = processName
        self.connectionCount = connectionCount
        self.remoteEndpoints = remoteEndpoints
    }
}

/// Rich network snapshot for the dedicated Network screen.
public struct NetworkDetailSnapshot: Sendable, Equatable {
    public var aggregate: NetworkMetrics
    public var interfaces: [NetworkInterfaceInfo]
    public var dnsServers: [String]
    public var pathStatus: NetworkPathStatus
    public var isExpensive: Bool
    public var isConstrained: Bool
    public var usesWiFi: Bool
    public var usesEthernet: Bool
    public var usesCellular: Bool
    public var primaryIPv4: String?
    public var connections: [NetworkConnection]
    public var appSummaries: [NetworkAppSummary]
    public var note: String
    public var sampledAt: Date

    public init(
        aggregate: NetworkMetrics,
        interfaces: [NetworkInterfaceInfo],
        dnsServers: [String],
        pathStatus: NetworkPathStatus,
        isExpensive: Bool,
        isConstrained: Bool,
        usesWiFi: Bool,
        usesEthernet: Bool,
        usesCellular: Bool,
        primaryIPv4: String?,
        connections: [NetworkConnection] = [],
        appSummaries: [NetworkAppSummary] = [],
        note: String,
        sampledAt: Date = .now
    ) {
        self.aggregate = aggregate
        self.interfaces = interfaces
        self.dnsServers = dnsServers
        self.pathStatus = pathStatus
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.usesWiFi = usesWiFi
        self.usesEthernet = usesEthernet
        self.usesCellular = usesCellular
        self.primaryIPv4 = primaryIPv4
        self.connections = connections
        self.appSummaries = appSummaries
        self.note = note
        self.sampledAt = sampledAt
    }
}

public struct ProcessMemoryInfo: Sendable, Equatable, Identifiable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    public var bundleIdentifier: String?
    public var residentBytes: UInt64

    public init(pid: Int32, name: String, bundleIdentifier: String? = nil, residentBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.residentBytes = residentBytes
    }
}

/// Per-process energy from `proc_pid_rusage` (`ri_energy_nj`) deltas.
public struct ProcessEnergyInfo: Sendable, Equatable, Identifiable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    /// Instantaneous power from successive samples (milliwatts).
    public var milliwatts: Double?
    /// Lifetime energy since process start (joules).
    public var lifetimeJoules: Double
    /// Sort key: prefer milliwatts, else lifetime joules.
    public var rankScore: Double

    public init(
        pid: Int32,
        name: String,
        milliwatts: Double? = nil,
        lifetimeJoules: Double,
        rankScore: Double
    ) {
        self.pid = pid
        self.name = name
        self.milliwatts = milliwatts
        self.lifetimeJoules = lifetimeJoules
        self.rankScore = rankScore
    }
}

public struct ThermalMetrics: Sendable, Equatable {
    public var cpuCelsius: Double?
    public var available: Bool
    public var unavailableReason: String?

    public init(cpuCelsius: Double? = nil, available: Bool, unavailableReason: String? = nil) {
        self.cpuCelsius = cpuCelsius
        self.available = available
        self.unavailableReason = unavailableReason
    }

    public static let unavailable = ThermalMetrics(
        available: false,
        unavailableReason: "Temperature sensors are not exposed via a supported public API on this Mac."
    )
}

public struct DiskHealthMetrics: Sendable, Equatable {
    public var volumePath: String
    public var fileSystem: String
    public var smartStatus: String?
    public var mediumType: String?
    public var temperatureCelsius: Double?
    public var wearLevelPercent: Double?
    public var available: Bool
    public var unavailableReason: String?
    public var sourceDescription: String

    public init(
        volumePath: String,
        fileSystem: String,
        smartStatus: String? = nil,
        mediumType: String? = nil,
        temperatureCelsius: Double? = nil,
        wearLevelPercent: Double? = nil,
        available: Bool,
        unavailableReason: String? = nil,
        sourceDescription: String
    ) {
        self.volumePath = volumePath
        self.fileSystem = fileSystem
        self.smartStatus = smartStatus
        self.mediumType = mediumType
        self.temperatureCelsius = temperatureCelsius
        self.wearLevelPercent = wearLevelPercent
        self.available = available
        self.unavailableReason = unavailableReason
        self.sourceDescription = sourceDescription
    }
}

/// Immutable point-in-time system snapshot for the dashboard.
public struct SystemSnapshot: Sendable, Equatable {
    public var cpu: CPUMetrics
    public var memory: MemoryMetrics
    public var volumes: [DiskVolumeMetrics]
    public var battery: BatteryMetrics
    public var network: NetworkMetrics
    public var topProcesses: [ProcessMemoryInfo]
    public var topEnergyProcesses: [ProcessEnergyInfo]
    public var cpuProcessGroups: [CPUProcessGroup]
    public var thermal: ThermalMetrics
    public var sampledAt: Date

    public init(
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        volumes: [DiskVolumeMetrics],
        battery: BatteryMetrics,
        network: NetworkMetrics,
        topProcesses: [ProcessMemoryInfo],
        topEnergyProcesses: [ProcessEnergyInfo] = [],
        cpuProcessGroups: [CPUProcessGroup] = [],
        thermal: ThermalMetrics,
        sampledAt: Date = .now
    ) {
        self.cpu = cpu
        self.memory = memory
        self.volumes = volumes
        self.battery = battery
        self.network = network
        self.topProcesses = topProcesses
        self.topEnergyProcesses = topEnergyProcesses
        self.cpuProcessGroups = cpuProcessGroups
        self.thermal = thermal
        self.sampledAt = sampledAt
    }
}
