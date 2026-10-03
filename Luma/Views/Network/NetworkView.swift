import SwiftUI
import LumaCore
import LumaSupport
import LumaUI

struct NetworkView: View {
    var model: NetworkViewModel

    @State private var appsExpanded = false
    @State private var connectionsExpanded = false
    @State private var interfacesExpanded = false
    @State private var addressesExpanded = false
    @State private var dnsExpanded = false
    @State private var confirmNetworkRefresh = false
    /// App PIDs whose remote endpoint lists are fully expanded.
    @State private var expandedAppRemotes: Set<Int32> = []
    @AppStorage(ListCardLayoutKeys.networkApps) private var appsLayout: ListCardLayout = .list
    @AppStorage(ListCardLayoutKeys.networkConnections) private var connectionsLayout: ListCardLayout = .list
    @AppStorage(ListCardLayoutKeys.networkInterfaces) private var interfacesLayout: ListCardLayout = .list
    @State private var appsSort: NetworkAppSort = .connections
    @State private var connectionsSort: NetworkConnectionSort = .process

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                if let snap = model.snapshot {
                    overview(snap)
                    pathCard(snap)
                    networkRefreshCard
                    appsSection(snap)
                    connectionsSection(snap)
                    addressesSection(snap)
                    interfacesSection(snap)
                    dnsSection(snap)
                    Text(LocalizedStringKey(snap.note))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView("Reading network…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Network")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task { model.start() }
        .confirmationDialog(
            "Refresh network stack?",
            isPresented: $confirmNetworkRefresh,
            titleVisibility: .visible
        ) {
            Button("Refresh Network") {
                Task { await model.refreshNetworkStack() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.bounceWiFiOnRefresh
                ? "Flushes DNS, renews DHCP on Wi‑Fi/Ethernet, then briefly turns Wi‑Fi off and on. macOS will ask for your admin password. Does not uninstall VPN apps or force-kill every tunnel."
                : "Flushes DNS and renews DHCP on Wi‑Fi/Ethernet — a soft network restart without rebooting. macOS will ask for your admin password. Does not uninstall VPN apps or force-kill every tunnel.")
        }
    }

    private var networkRefreshCard: some View {
        MetricCard(title: "After VPN / soft restart", systemImage: "arrow.triangle.2.circlepath", accent: LumaTheme.network) {
            Text("VPN disconnect can leave sticky DNS or DHCP state. This refreshes the local stack without rebooting the Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.tunnelInterfaceNames.isEmpty {
                Text(LumaL10n.format(
                    "Tunnel interfaces now: %@",
                    model.tunnelInterfaceNames.joined(separator: ", ")
                ))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            } else {
                Text("No tunnel interfaces (utun / ipsec / ppp) listed right now.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Toggle("Also bounce Wi‑Fi (brief disconnect)", isOn: Binding(
                get: { model.bounceWiFiOnRefresh },
                set: { model.bounceWiFiOnRefresh = $0 }
            ))
            .disabled(model.isRefreshingNetwork)

            if model.isRefreshingNetwork {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing network…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    confirmNetworkRefresh = true
                } label: {
                    Label("Refresh Network", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .tint(LumaTheme.network)
                .disabled(model.isRefreshingNetwork)
            }

            if let error = model.refreshErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if let report = model.refreshReport {
                if report.cancelled {
                    Text("Cancelled — no changes applied.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !report.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LumaL10n.format(
                            "Last run: %lld ok, %lld failed",
                            Int64(report.succeededCount),
                            Int64(report.failedCount)
                        ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        ForEach(report.steps) { step in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: step.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(step.succeeded ? LumaTheme.network : .red)
                                    .font(.caption)
                                Text(LocalizedStringKey(step.title))
                                    .font(.caption)
                                if let detail = step.detail {
                                    Text(detail)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func overview(_ snap: NetworkDetailSnapshot) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                MetricCard(title: "Download", systemImage: "arrow.down.circle.fill", accent: LumaTheme.network) {
                    Text(ByteFormatters.rateString(bytesPerSecond: snap.aggregate.bytesInPerSecond))
                        .font(.title.monospacedDigit().weight(.semibold))
                    rateBar(model.inHistory, tint: LumaTheme.network)
                    Text(LumaL10n.format("Total in %@", ByteFormatters.string(for: snap.aggregate.totalBytesIn)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Wi‑Fi / Ethernet")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                MetricCard(title: "Upload", systemImage: "arrow.up.circle.fill", accent: LumaTheme.cpu) {
                    Text(ByteFormatters.rateString(bytesPerSecond: snap.aggregate.bytesOutPerSecond))
                        .font(.title.monospacedDigit().weight(.semibold))
                    rateBar(model.outHistory, tint: LumaTheme.cpu)
                    Text(LumaL10n.format("Total out %@", ByteFormatters.string(for: snap.aggregate.totalBytesOut)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Wi‑Fi / Ethernet")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func pathCard(_ snap: NetworkDetailSnapshot) -> some View {
        MetricCard(title: "Connection", systemImage: "antenna.radiowaves.left.and.right", accent: LumaTheme.network) {
            HStack(spacing: 10) {
                statusChip(LocalizedStringKey(snap.pathStatus.rawValue), active: snap.pathStatus == .satisfied)
                if snap.usesWiFi { statusChip("Wi‑Fi", active: true) }
                if snap.usesEthernet { statusChip("Ethernet", active: true) }
                if snap.usesCellular { statusChip("Cellular", active: true) }
                if snap.isExpensive { statusChip("Expensive", active: true) }
                if snap.isConstrained { statusChip("Constrained", active: true) }
                Spacer(minLength: 0)
            }
            if let ip = snap.primaryIPv4 {
                LabeledContent("Primary IPv4") {
                    Text(ip).monospacedDigit()
                }
            }
        }
    }

    // MARK: - Collapsible sections

    private func appsSection(_ snap: NetworkDetailSnapshot) -> some View {
        collapsibleCard(
            title: "Apps talking on the network",
            systemImage: "app.badge",
            accent: LumaTheme.battery,
            countText: LumaL10n.format("%lld apps", Int64(snap.appSummaries.count)),
            isExpanded: $appsExpanded
        ) {
            Text("Open sockets per app (not byte volume — macOS does not expose honest per-app rates via public APIs).")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if snap.appSummaries.isEmpty {
                Text("No remote sockets visible yet")
                    .foregroundStyle(.secondary)
            } else {
                let apps = appsSort.sorted(snap.appSummaries)
                sectionChrome(layout: $appsLayout) {
                    Picker("Sort", selection: $appsSort) {
                        ForEach(NetworkAppSort.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help(Text("Sort"))
                }

                if appsLayout == .list {
                    VStack(spacing: 0) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            appRow(app)
                                .padding(.vertical, 8)
                            if index < apps.count - 1 {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(apps) { app in
                            appCard(app)
                        }
                    }
                }
            }
        }
    }

    private func appRow(_ app: NetworkAppSummary) -> some View {
        let showAll = expandedAppRemotes.contains(app.pid)
        let visible = showAll ? app.remoteEndpoints : Array(app.remoteEndpoints.prefix(3))
        let hidden = app.remoteEndpoints.count - visible.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundStyle(LumaTheme.battery)
                    .frame(width: 18)
                Text(app.processName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(LumaL10n.format("%lld connections", Int64(app.connectionCount)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(visible, id: \.self) { endpoint in
                    Text(endpoint)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.leading, 26)

            if hidden > 0 {
                Button {
                    expandedAppRemotes.insert(app.pid)
                } label: {
                    Text(LumaL10n.format("Show %lld more", Int64(hidden)))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumaTheme.network)
                .padding(.leading, 26)
            } else if showAll, app.remoteEndpoints.count > 3 {
                Button {
                    expandedAppRemotes.remove(app.pid)
                } label: {
                    Text("Show less")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 26)
            }
        }
    }

    private func appCard(_ app: NetworkAppSummary) -> some View {
        let showAll = expandedAppRemotes.contains(app.pid)
        let visible = showAll ? app.remoteEndpoints : Array(app.remoteEndpoints.prefix(4))
        let hidden = app.remoteEndpoints.count - visible.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumaTheme.battery.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "app.fill")
                        .foregroundStyle(LumaTheme.battery)
                }
                Spacer(minLength: 8)
                Text("\(app.connectionCount)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            Text(app.processName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(visible, id: \.self) { endpoint in
                    Text(endpoint)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if hidden > 0 {
                Button {
                    expandedAppRemotes.insert(app.pid)
                } label: {
                    Text(LumaL10n.format("Show %lld more", Int64(hidden)))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumaTheme.network)
            } else if showAll, app.remoteEndpoints.count > 4 {
                Button {
                    expandedAppRemotes.remove(app.pid)
                } label: {
                    Text("Show less")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(tileBackground)
    }

    private func connectionsSection(_ snap: NetworkDetailSnapshot) -> some View {
        collapsibleCard(
            title: "Active connections",
            systemImage: "arrow.left.arrow.right",
            accent: LumaTheme.cpu,
            countText: LumaL10n.format("%lld connections", Int64(snap.connections.count)),
            isExpanded: $connectionsExpanded
        ) {
            if snap.connections.isEmpty {
                Text("No remote connections found")
                    .foregroundStyle(.secondary)
            } else {
                let connections = connectionsSort.sorted(snap.connections)
                sectionChrome(layout: $connectionsLayout) {
                    Picker("Sort", selection: $connectionsSort) {
                        ForEach(NetworkConnectionSort.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help(Text("Sort"))
                }

                if connectionsLayout == .list {
                    VStack(spacing: 0) {
                        ForEach(Array(connections.enumerated()), id: \.element.id) { index, connection in
                            connectionRow(connection)
                                .padding(.vertical, 8)
                            if index < connections.count - 1 {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(connections) { connection in
                            connectionCard(connection)
                        }
                    }
                }
            }
        }
    }

    private func connectionRow(_ connection: NetworkConnection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(connection.processName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(connection.protocolKind.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                if let state = connection.tcpState {
                    Text(LocalizedStringKey(state))
                        .font(.caption2)
                        .foregroundStyle(state == "established" ? LumaTheme.network : .secondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(connection.localEndpoint)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(connection.remoteEndpoint)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .textSelection(.enabled)
                if let service = wellKnownService(connection.remotePort) {
                    Text(service)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func connectionCard(_ connection: NetworkConnection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumaTheme.cpu.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(LumaTheme.cpu)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(connection.protocolKind.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    if let state = connection.tcpState {
                        Text(LocalizedStringKey(state))
                            .font(.caption2)
                            .foregroundStyle(state == "established" ? LumaTheme.network : .secondary)
                    }
                }
            }

            Text(connection.processName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 4) {
                labeledEndpoint("Local", connection.localEndpoint)
                labeledEndpoint("Remote", connection.remoteEndpoint)
                if let service = wellKnownService(connection.remotePort) {
                    Text(service)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(tileBackground)
    }

    private func labeledEndpoint(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func addressesSection(_ snap: NetworkDetailSnapshot) -> some View {
        let ipv4 = Array(Set(snap.interfaces.flatMap(\.ipv4Addresses))).sorted()
        let ipv6 = Array(Set(snap.interfaces.flatMap(\.ipv6Addresses))).sorted()
        return collapsibleCard(
            title: "Local addresses",
            systemImage: "number",
            accent: LumaTheme.memory,
            countText: LumaL10n.format("%lld addresses", Int64(ipv4.count + ipv6.count)),
            isExpanded: $addressesExpanded
        ) {
            if ipv4.isEmpty && ipv6.isEmpty {
                Text("No local addresses found")
                    .foregroundStyle(.secondary)
            } else {
                if !ipv4.isEmpty {
                    Text("IPv4").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(ipv4, id: \.self) { ip in
                        Text(ip).font(.body.monospacedDigit()).textSelection(.enabled)
                    }
                }
                if !ipv6.isEmpty {
                    Text("IPv6").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(ipv6, id: \.self) { ip in
                        Text(ip).font(.callout.monospacedDigit()).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func interfacesSection(_ snap: NetworkDetailSnapshot) -> some View {
        let ifaces = snap.interfaces.filter { $0.isUp || !$0.ipv4Addresses.isEmpty || $0.isRunning }
        return collapsibleCard(
            title: "Interfaces",
            systemImage: "switch.2",
            accent: LumaTheme.storage,
            countText: LumaL10n.format("%lld interfaces", Int64(ifaces.count)),
            isExpanded: $interfacesExpanded
        ) {
            if ifaces.isEmpty {
                Text("No interfaces found")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    layoutToolbar(selection: $interfacesLayout)
                }

                if interfacesLayout == .list {
                    VStack(spacing: 0) {
                        ForEach(Array(ifaces.enumerated()), id: \.element.id) { index, iface in
                            interfaceRow(iface)
                                .padding(.vertical, 8)
                            if index < ifaces.count - 1 {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(ifaces) { iface in
                            interfaceCard(iface)
                        }
                    }
                }
            }
        }
    }

    private func interfaceRow(_ iface: NetworkInterfaceInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(iface.name)
                    .font(.headline.monospacedDigit())
                Text(LocalizedStringKey(iface.kindLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(iface.isRunning ? "Running" : (iface.isUp ? "Up" : "Down"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iface.isRunning ? LumaTheme.network : .secondary)
            }
            HStack(spacing: 16) {
                Label(ByteFormatters.rateString(bytesPerSecond: iface.bytesInPerSecond), systemImage: "arrow.down")
                Label(ByteFormatters.rateString(bytesPerSecond: iface.bytesOutPerSecond), systemImage: "arrow.up")
                Spacer()
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if !iface.ipv4Addresses.isEmpty {
                Text(iface.ipv4Addresses.joined(separator: ", "))
                    .font(.caption.monospacedDigit())
                    .textSelection(.enabled)
            }
            if !iface.ipv6Addresses.isEmpty {
                Text(iface.ipv6Addresses.joined(separator: ", "))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let mac = iface.macAddress {
                Text(LumaL10n.format("MAC %@", mac))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private func interfaceCard(_ iface: NetworkInterfaceInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumaTheme.storage.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "switch.2")
                        .foregroundStyle(LumaTheme.storage)
                }
                Spacer(minLength: 8)
                Text(iface.isRunning ? "Running" : (iface.isUp ? "Up" : "Down"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iface.isRunning ? LumaTheme.network : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(iface.name)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(LocalizedStringKey(iface.kindLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label(ByteFormatters.rateString(bytesPerSecond: iface.bytesInPerSecond), systemImage: "arrow.down")
                Label(ByteFormatters.rateString(bytesPerSecond: iface.bytesOutPerSecond), systemImage: "arrow.up")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if let ip = iface.ipv4Addresses.first {
                Text(ip)
                    .font(.caption.monospacedDigit())
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(tileBackground)
    }

    private func dnsSection(_ snap: NetworkDetailSnapshot) -> some View {
        collapsibleCard(
            title: "DNS",
            systemImage: "server.rack",
            accent: LumaTheme.battery,
            countText: LumaL10n.format("%lld servers", Int64(snap.dnsServers.count)),
            isExpanded: $dnsExpanded
        ) {
            if snap.dnsServers.isEmpty {
                Text("No DNS servers reported")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snap.dnsServers, id: \.self) { server in
                    Text(server).font(.body.monospacedDigit()).textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Shared chrome

    private func sectionChrome<SortChrome: View>(
        layout: Binding<ListCardLayout>,
        @ViewBuilder sort: () -> SortChrome
    ) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            sort()
            layoutToolbar(selection: layout)
        }
    }

    private func layoutToolbar(selection: Binding<ListCardLayout>) -> some View {
        Picker(selection: selection) {
            ForEach(ListCardLayout.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
                    .help(mode.title)
            }
        } label: {
            Text("Layout")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 88)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(Text("Layout"))
        .help(Text("Layout"))
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    private func collapsibleCard<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        accent: Color,
        countText: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 22, height: 22)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(countText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(.background.secondary)
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private func wellKnownService(_ port: Int) -> String? {
        switch port {
        case 80: return "HTTP"
        case 443: return "HTTPS"
        case 22: return "SSH"
        case 53: return "DNS"
        case 3306: return "MySQL"
        case 5432: return "Postgres"
        case 6379: return "Redis"
        case 27017: return "MongoDB"
        case 5228: return "Google"
        default: return nil
        }
    }

    private func rateBar(_ values: [Double], tint: Color) -> some View {
        let window = Array(values.suffix(40))
        let peak = max(window.max() ?? 0, 256_000) // at least ~256 KB/s full scale
        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(window.enumerated()), id: \.offset) { _, value in
                    let normalized = min(max(value / peak, 0), 1)
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(tint.opacity(0.75))
                        .frame(width: max((geo.size.width - 40) / 40, 1), height: max(2, geo.size.height * normalized))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 36)
        .accessibilityHidden(true)
    }

    private func statusChip(_ title: LocalizedStringKey, active: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? LumaTheme.network.opacity(0.18) : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(active ? LumaTheme.network : .secondary)
    }
}
