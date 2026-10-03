import AppKit
import Charts
import SwiftUI
import LumaCore
import LumaStorage
import LumaSupport
import LumaUI

private struct LiveScanProgressBlock: View {
    let label: String
    let fraction: Double
    var accent: Color = LumaTheme.storage

    private var clamped: Double {
        fraction.isFinite ? min(max(fraction, 0), 1) : 0
    }

    private var percentText: String {
        "\(Int((clamped * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(percentText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityLabel(Text(percentText))
            }
            ProgressView(value: clamped)
                .tint(accent)
                .animation(.easeOut(duration: 0.15), value: clamped)
        }
    }
}

struct StorageView: View {
    @Bindable var model: StorageViewModel
    @AppStorage(ListCardLayoutKeys.storage) private var layoutMode: ListCardLayout = .list

    private let folderBrowserScrollID = "storage.folderBrowser"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introBanner

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let volume = model.volume {
                        volumeCard(volume)
                    }

                    if model.isScanning {
                        scanningCard
                        if let result = model.result {
                            overviewCard(result, live: true)
                            if !model.displayFolders.isEmpty || model.isDrilling {
                                foldersCard(model.displayFolders)
                                    .id(folderBrowserScrollID)
                            }
                        }
                    } else if let result = model.result {
                        overviewCard(result, live: false)
                        if !model.otherFolders.isEmpty {
                            otherBreakdownCard
                        }
                        foldersCard(model.displayFolders)
                            .id(folderBrowserScrollID)
                    } else {
                        emptyCard
                    }
                }
                .padding(20)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.drillStack.count) { _, _ in
                focusFolderBrowser(proxy)
            }
            .onChange(of: model.isDrilling) { _, drilling in
                if drilling { focusFolderBrowser(proxy) }
            }
        }
        .navigationTitle("Storage")
        .onAppear { model.refreshVolume() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isScanning {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button {
                        model.scan()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func focusFolderBrowser(_ proxy: ScrollViewProxy) {
        // Let SwiftUI commit the new browser chrome before scrolling.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(folderBrowserScrollID, anchor: .top)
            }
        }
    }

    // MARK: - Banner

    private var introBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .font(.title3)
                .foregroundStyle(LumaTheme.storage)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage map")
                    .font(.headline)
                Text("Disk used/free comes from the system. Folder breakdowns scan reclaim targets or your home — never a slow crawl of /System.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.storage.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.storage.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func volumeCard(_ volume: DiskVolumeMetrics) -> some View {
        MetricCard(title: "This Mac disk", systemImage: "internaldrive", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ByteFormatters.string(for: volume.usedBytes))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(LumaL10n.format(
                        "%@ free of %@",
                        ByteFormatters.string(for: volume.freeBytes),
                        ByteFormatters.string(for: volume.totalBytes)
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                ProgressView(value: volume.totalBytes > 0
                    ? Double(volume.usedBytes) / Double(volume.totalBytes)
                    : 0)
                    .tint(LumaTheme.storage)

                Text("Full-disk used space is instant from APFS — no folder-by-folder walk of the whole volume.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Scan scope", selection: $model.scope) {
                ForEach(StorageScanScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isScanning)

            Text(model.scope.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scanningCard: some View {
        MetricCard(title: "Scanning…", systemImage: "magnifyingglass", accent: LumaTheme.storage) {
            LiveScanProgressBlock(
                label: model.progressLabel.isEmpty ? String(localized: "Scanning…") : model.progressLabel,
                fraction: model.progressFraction,
                accent: LumaTheme.storage
            )
        }
    }

    private var emptyCard: some View {
        MetricCard(title: "Analyze storage", systemImage: "externaldrive", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose what to scan, then start. Disk capacity above is already the full volume.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                scopePicker
                Button {
                    model.scan()
                } label: {
                    Label("Scan now", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func overviewCard(_ result: StorageScanResult, live: Bool) -> some View {
        MetricCard(
            title: live ? "Breakdown so far" : "Breakdown",
            systemImage: "chart.pie.fill",
            accent: LumaTheme.storage
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ByteFormatters.string(for: model.totalBytes))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(live ? "found so far" : "scanned locations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if !live, let volume = model.volume, volume.usedBytes > 0 {
                    Text(LumaL10n.format(
                        "Scanned %@ · disk used %@ — leftover slice is unwalked disk, not a mystery home pile.",
                        ByteFormatters.string(for: model.totalBytes),
                        ByteFormatters.string(for: volume.usedBytes)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !live {
                    scopePicker
                    Button {
                        model.scan()
                    } label: {
                        Label("Scan again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

                let categories = live ? result.categories : model.breakdownCategories
                if categories.isEmpty {
                    Text(live ? "Waiting for the first folder…" : "No measurable folders found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    CategoryBytesChart(
                        slices: categories.map {
                            .init(label: $0.category.title, bytes: $0.byteCount)
                        }
                    )
                    .frame(height: 220)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
                        ForEach(categories) { cat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cat.category.tint)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cat.category.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                    Text(ByteFormatters.string(for: cat.byteCount))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var otherBreakdownCard: some View {
        MetricCard(title: "What’s inside Other", systemImage: "folder.badge.questionmark", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 10) {
                Text("These folders were scanned. Other is not free space — it is files that did not match Photos, Mail, apps, or developer tools. Open a row to see the next level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(model.otherFolders) { node in
                    StorageNodeRow(
                        node: node,
                        onOpen: { model.drill(into: node) },
                        onReveal: { model.revealInFinder(node) }
                    )
                    if node.id != model.otherFolders.last?.id {
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

    private func foldersCard(_ folders: [StorageNode]) -> some View {
        MetricCard(
            title: model.isDrilling ? "Folder browser" : "Largest folders",
            systemImage: model.isDrilling ? "internaldrive" : "folder.fill",
            accent: LumaTheme.storage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if model.isDrilling {
                    drillChrome
                }

                HStack(alignment: .center, spacing: 10) {
                    if model.isDrilling {
                        Text(LumaL10n.format(
                            "%lld folders · %lld files",
                            Int64(model.browseFolderCount),
                            Int64(model.browseFileCount)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    } else {
                        Text(LumaL10n.format("%@ locations", "\(folders.count)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Picker("Sort", selection: $model.folderSort) {
                        ForEach(SizeNameSort.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help(Text("Sort"))
                    .disabled(model.isLoadingDrill && folders.isEmpty)
                    Picker(selection: $layoutMode) {
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

                if !model.isDrilling {
                    Text("Open a folder here to browse its files and folders with sizes — like Finder, inside Luma.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let drillError = model.drillError {
                    Text(drillError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if model.isLoadingDrill {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        if model.drillProgressName.isEmpty {
                            Text("Reading folder…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(LumaL10n.format("Measuring %@", model.drillProgressName))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }

                if folders.isEmpty && !model.isLoadingDrill {
                    Text(model.isDrilling
                        ? "This folder is empty (or nothing readable)."
                        : "No folders above the size threshold.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !folders.isEmpty {
                    Group {
                        if layoutMode == .list {
                            LazyVStack(spacing: 0) {
                                ForEach(folders) { node in
                                    StorageNodeRow(
                                        node: node,
                                        browsing: model.isDrilling,
                                        onOpen: { model.drill(into: node) },
                                        onReveal: { model.revealInFinder(node) }
                                    )
                                    if node.id != folders.last?.id {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                                ForEach(folders) { node in
                                    StorageNodeCard(
                                        node: node,
                                        browsing: model.isDrilling,
                                        onOpen: { model.drill(into: node) },
                                        onReveal: { model.revealInFinder(node) }
                                    )
                                }
                            }
                        }
                    }
                    // Progressive measure updates change height a lot — don't animate layout thrash.
                    .animation(nil, value: folders.count)
                }
            }
            // Keep browser footprint stable while measuring so the outer ScrollView doesn't jump.
            .frame(minHeight: model.isDrilling ? 360 : nil, alignment: .top)
        }
    }

    private var drillChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.drillBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Button("All folders") {
                    model.drillToRoot()
                }
                .buttonStyle(.borderless)

                Spacer(minLength: 0)

                if let parent = model.drillParent {
                    Button {
                        model.revealInFinder(parent)
                    } label: {
                        Label("Show in Finder", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Button("Largest") {
                        model.drillToRoot()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumaTheme.storage)

                    ForEach(Array(model.drillStack.enumerated()), id: \.offset) { index, node in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Button(node.name) {
                            model.drillToIndex(index)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(index == model.drillStack.count - 1 ? .semibold : .regular))
                        .foregroundStyle(index == model.drillStack.count - 1 ? .primary : LumaTheme.storage)
                        .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Rows & cards

private struct StorageNodeRow: View {
    let node: StorageNode
    var browsing: Bool = false
    let onOpen: () -> Void
    let onReveal: () -> Void
    @State private var isHovered = false

    private var canBrowse: Bool { storageNodeCanBrowse(node) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: storageNodeSymbol(node))
                .font(.body)
                .foregroundStyle(node.category.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(browsing
                     ? (canBrowse ? LumaL10n.string("Folder") : LumaL10n.string("File"))
                     : abbreviatedPath(node.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(ByteFormatters.string(for: node.byteCount))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            if canBrowse {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHovered ? AnyShapeStyle(LumaTheme.storage) : AnyShapeStyle(.tertiary))
            }

            Button(action: onReveal) {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help(canBrowse ? Text("Open in Finder") : Text("Reveal in Finder"))
            .accessibilityLabel(canBrowse ? Text("Open in Finder") : Text("Reveal in Finder"))
            .pointerStyle(.link)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(canBrowse && isHovered ? LumaTheme.storage.opacity(0.10) : .clear)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .pointerStyle(canBrowse ? .link : .default)
        .help(canBrowse ? Text("Open folder") : Text(""))
        .onTapGesture {
            if canBrowse { onOpen() }
        }
        .contextMenu {
            if canBrowse {
                Button("Open in Luma", action: onOpen)
            }
            Button(canBrowse ? "Open in Finder" : "Reveal in Finder", action: onReveal)
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.path, forType: .string)
            }
        }
    }
}

private struct StorageNodeCard: View {
    let node: StorageNode
    var browsing: Bool = false
    let onOpen: () -> Void
    let onReveal: () -> Void
    @State private var isHovered = false

    private var canBrowse: Bool { storageNodeCanBrowse(node) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(node.category.tint.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: storageNodeSymbol(node))
                        .foregroundStyle(node.category.tint)
                }
                Spacer(minLength: 8)
                Button(action: onReveal) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderless)
                .help(canBrowse ? Text("Open in Finder") : Text("Reveal in Finder"))
                .pointerStyle(.link)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if canBrowse {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isHovered ? AnyShapeStyle(LumaTheme.storage) : AnyShapeStyle(.tertiary))
                    }
                }
                Text(browsing
                     ? (canBrowse ? LumaL10n.string("Folder") : LumaL10n.string("File"))
                     : abbreviatedPath(node.path))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text(ByteFormatters.string(for: node.byteCount))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background { cardBackground }
        .overlay { cardBorder }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .pointerStyle(canBrowse ? .link : .default)
        .help(canBrowse ? Text("Open folder") : Text(""))
        .contextMenu {
            if canBrowse {
                Button("Open in Luma", action: onOpen)
            }
            Button(canBrowse ? "Open in Finder" : "Reveal in Finder", action: onReveal)
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.path, forType: .string)
            }
        }
        .onTapGesture {
            if canBrowse { onOpen() }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(canBrowse && isHovered
                  ? LumaTheme.storage.opacity(0.10)
                  : Color.primary.opacity(0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                canBrowse && isHovered ? LumaTheme.storage.opacity(0.28) : Color.primary.opacity(0.06),
                lineWidth: 1
            )
    }
}

/// Real folders only — `.app` / packages are opaque (size shown, not browsable in Luma).
private func storageNodeCanBrowse(_ node: StorageNode) -> Bool {
    guard node.isDirectory else { return false }
    let url = URL(fileURLWithPath: node.path)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
        return false
    }
    return (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true
}

private func storageNodeSymbol(_ node: StorageNode) -> String {
    if node.name.hasSuffix(".app") { return "app.fill" }
    if storageNodeCanBrowse(node) { return "folder.fill" }
    return "doc.fill"
}

private func abbreviatedPath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

private extension StorageCategory {
    var tint: Color {
        switch self {
        case .applications: .blue
        case .caches: .orange
        case .downloads: .cyan
        case .developer: .green
        case .docker: .indigo
        case .xcode: .yellow
        case .simulator: .purple
        case .android: Color(red: 0.24, green: 0.78, blue: 0.45)
        case .flutter: .mint
        case .reactNative: .teal
        case .node: Color(red: 0.55, green: 0.80, blue: 0.35)
        case .homebrew: .brown
        case .documents: .pink
        case .photos: Color(red: 0.95, green: 0.45, blue: 0.55)
        case .movies: Color(red: 0.55, green: 0.35, blue: 0.85)
        case .music: Color(red: 0.95, green: 0.35, blue: 0.45)
        case .desktop: Color(red: 0.35, green: 0.6, blue: 0.9)
        case .iCloud: Color(red: 0.35, green: 0.55, blue: 0.95)
        case .mail: Color(red: 0.25, green: 0.55, blue: 0.85)
        case .messages: Color(red: 0.3, green: 0.75, blue: 0.45)
        case .appSupport: Color(red: 0.55, green: 0.5, blue: 0.45)
        case .containers: Color(red: 0.45, green: 0.55, blue: 0.5)
        case .virtualMachines: Color(red: 0.4, green: 0.4, blue: 0.7)
        case .other: .gray
        case .system: Color(white: 0.55)
        }
    }
}

// MARK: - Large files & duplicates

struct LargeFilesView: View {
    @Bindable var model: LargeFilesViewModel
    @AppStorage(ListCardLayoutKeys.largeFiles) private var layoutMode: ListCardLayout = .list

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introBanner

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if model.isScanning {
                    scanningCard
                    if !model.hits.isEmpty {
                        resultsCard
                    }
                } else if !model.hasScanned {
                    emptyStartCard
                } else if model.hits.isEmpty {
                    emptyResultCard
                } else {
                    resultsCard
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Large Files")
        .onAppear { PermissionGate.shared.refreshFullDiskAccessProbe() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isScanning {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button {
                        model.scan()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var introBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.title3)
                .foregroundStyle(LumaTheme.storage)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Large Files")
                    .font(.headline)
                Text("Searches your home folder and Applications for big files. Full Disk Access unlocks protected Library paths. System folders stay off-limits.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.storage.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.storage.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("What to scan", selection: $model.scope) {
                ForEach(FileScanScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isScanning)

            Text(model.scope.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var thresholdPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Threshold", selection: Binding(
                get: { model.thresholdChoice },
                set: { model.selectThreshold($0) }
            )) {
                ForEach(LargeFileThresholdChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isScanning)

            if model.thresholdChoice == .custom {
                HStack(spacing: 10) {
                    Text("Minimum")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField(
                        "MB",
                        value: $model.customThresholdMB,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .multilineTextAlignment(.trailing)
                    Text("MB")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Stepper(
                        "",
                        value: $model.customThresholdMB,
                        in: 1...1_048_576,
                        step: 50
                    )
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                .disabled(model.isScanning)
            }
        }
    }

    private var scanningCard: some View {
        MetricCard(title: "Scanning…", systemImage: "magnifyingglass", accent: LumaTheme.storage) {
            LiveScanProgressBlock(
                label: model.progressLabel.isEmpty ? LumaL10n.string("Scanning…") : model.progressLabel,
                fraction: model.progressFraction,
                accent: LumaTheme.storage
            )
        }
    }

    private var emptyStartCard: some View {
        MetricCard(title: "Find large files", systemImage: "doc.badge.ellipsis", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose where to look and a size threshold, then start. Empty results still show a clear summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                scopePicker
                thresholdPicker
                if !PermissionGate.shared.lastProbeSucceeded {
                    Text("Tip: grant Full Disk Access in Settings so protected Library folders (like Safari) are included.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    model.scan()
                } label: {
                    Label("Scan now", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyResultCard: some View {
        MetricCard(title: "No large files found", systemImage: "checkmark.seal", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumaL10n.format(
                    "Examined %lld files. None matched %@.",
                    Int64(model.filesExamined),
                    model.thresholdTitle
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if model.filesExamined == 0 {
                    Text("No readable files in the selected scope, or access was blocked. Try Full Disk Access or a wider scope.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Try a lower threshold (for example > 100 MB), or scan again after adding bigger files.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                scopePicker
                thresholdPicker
                Button {
                    model.scan()
                } label: {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var resultsCard: some View {
        MetricCard(
            title: model.isScanning ? "Matches so far" : "Largest matches",
            systemImage: "doc.fill",
            accent: LumaTheme.storage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(LumaL10n.format("%lld files", Int64(model.hits.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(LumaL10n.format("Examined %lld", Int64(model.filesExamined)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    layoutPicker
                }

                if !model.isScanning {
                    VStack(alignment: .leading, spacing: 10) {
                        scopePicker
                        HStack(alignment: .center, spacing: 12) {
                            thresholdPicker
                            Spacer(minLength: 8)
                            sortPicker
                        }
                    }
                } else {
                    HStack {
                        Spacer(minLength: 0)
                        sortPicker
                    }
                }

                let hits = model.sortedHits
                if layoutMode == .list {
                    LazyVStack(spacing: 0) {
                        ForEach(hits) { hit in
                            largeFileRow(hit)
                            if hit.id != hits.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(hits) { hit in
                            largeFileCard(hit)
                        }
                    }
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $model.sortMode) {
            ForEach(SizeNameSort.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help(Text("Sort"))
    }

    private var layoutPicker: some View {
        Picker(selection: Binding(
            get: { layoutMode },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    layoutMode = newValue
                }
            }
        )) {
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

    private func largeFileRow(_ hit: LargeFileHit) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(LumaTheme.storage)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(abbreviatedHomePath(hit.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(ByteFormatters.string(for: hit.byteCount))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                revealLargeFile(hit)
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.borderless)
            .help(Text("Reveal in Finder"))
            Button("Trash", role: .destructive) {
                trashLargeFile(hit)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Reveal in Finder") { revealLargeFile(hit) }
            Button("Move to Trash", role: .destructive) { trashLargeFile(hit) }
        }
    }

    private func largeFileCard(_ hit: LargeFileHit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumaTheme.storage.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "doc.fill")
                        .foregroundStyle(LumaTheme.storage)
                }
                Spacer(minLength: 8)
                Button {
                    revealLargeFile(hit)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderless)
                .help(Text("Reveal in Finder"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(hit.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(abbreviatedHomePath(hit.path))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            HStack {
                Text(ByteFormatters.string(for: hit.byteCount))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Spacer()
                Button("Trash", role: .destructive) {
                    trashLargeFile(hit)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button("Reveal in Finder") { revealLargeFile(hit) }
            Button("Move to Trash", role: .destructive) { trashLargeFile(hit) }
        }
        .onTapGesture { revealLargeFile(hit) }
    }

    private func revealLargeFile(_ hit: LargeFileHit) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: hit.path)])
    }

    private func trashLargeFile(_ hit: LargeFileHit) {
        try? FileIO.moveToTrash(URL(fileURLWithPath: hit.path))
        model.hits.removeAll { $0.id == hit.id }
    }

    private func abbreviatedHomePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct DuplicatesView: View {
    @Bindable var model: DuplicatesViewModel
    @AppStorage(ListCardLayoutKeys.duplicates) private var layoutMode: ListCardLayout = .list
    @State private var expandedGroups: Set<String> = []

    private let collapsedPathLimit = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introBanner

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if model.isScanning {
                    scanningCard
                    if !model.groups.isEmpty {
                        resultsCard
                    }
                } else if !model.hasScanned {
                    emptyStartCard
                } else if model.groups.isEmpty {
                    emptyResultCard
                } else {
                    resultsCard
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Duplicates")
        .onAppear { PermissionGate.shared.refreshFullDiskAccessProbe() }
        .onChange(of: model.isScanning) { _, scanning in
            if scanning { expandedGroups.removeAll() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isScanning {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button {
                        model.scan()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var introBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.on.doc.fill")
                .font(.title3)
                .foregroundStyle(LumaTheme.storage)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicates")
                    .font(.headline)
                Text("Finds identical files by size, then SHA-256 across your home folder and Applications. Full Disk Access unlocks protected Library paths. System stays off-limits.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.storage.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.storage.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("What to scan", selection: $model.scope) {
                ForEach(FileScanScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isScanning)

            Text(model.scope.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var thresholdPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Minimum size", selection: Binding(
                get: { model.minSizeChoice },
                set: { model.selectMinSize($0) }
            )) {
                ForEach(DuplicateMinSizeChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isScanning)

            if model.minSizeChoice == .custom {
                HStack(spacing: 10) {
                    Text("Minimum")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField(
                        "MB",
                        value: $model.customMinMB,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .multilineTextAlignment(.trailing)
                    Text("MB")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Stepper(
                        "",
                        value: $model.customMinMB,
                        in: 0.01...10_240,
                        step: 0.1
                    )
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                .disabled(model.isScanning)
            }
        }
    }

    private var scanningCard: some View {
        MetricCard(title: "Scanning…", systemImage: "magnifyingglass", accent: LumaTheme.storage) {
            LiveScanProgressBlock(
                label: model.progressLabel.isEmpty ? LumaL10n.string("Scanning…") : model.progressLabel,
                fraction: model.progressFraction,
                accent: LumaTheme.storage
            )
        }
    }

    private var emptyStartCard: some View {
        MetricCard(title: "Find duplicates by SHA-256", systemImage: "doc.on.doc", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Compare files that share the same size, then confirm with a full hash. Choose where to look first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                scopePicker
                thresholdPicker
                if !PermissionGate.shared.lastProbeSucceeded {
                    Text("Tip: grant Full Disk Access in Settings so protected Library folders (like Safari) are included.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    model.scan()
                } label: {
                    Label("Scan now", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyResultCard: some View {
        MetricCard(title: "No duplicates found", systemImage: "checkmark.seal", accent: LumaTheme.storage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumaL10n.format(
                    "Examined %lld files (%lld above %@). No identical groups.",
                    Int64(model.filesExamined),
                    Int64(model.filesAboveThreshold),
                    model.minSizeTitle
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if model.filesAboveThreshold == 0 {
                    Text("Try a lower minimum size, a wider scope, or Full Disk Access for protected Library folders.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if model.sizeCollisionBuckets == 0 {
                    Text("No two files share the same size above the threshold — so none can be duplicates.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                scopePicker
                thresholdPicker
                Button {
                    model.scan()
                } label: {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var resultsCard: some View {
        MetricCard(
            title: model.isScanning ? "Groups found so far" : "Duplicate groups",
            systemImage: "doc.on.doc.fill",
            accent: LumaTheme.storage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(LumaL10n.format("%lld groups", Int64(model.groups.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(LumaL10n.format(
                        "%@ reclaimable",
                        ByteFormatters.string(for: model.totalWastedBytes)
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    layoutPicker
                }

                if !model.isScanning {
                    VStack(alignment: .leading, spacing: 10) {
                        scopePicker
                        HStack(alignment: .center, spacing: 12) {
                            thresholdPicker
                            Spacer(minLength: 8)
                            sortPicker
                        }
                    }
                } else {
                    HStack {
                        Spacer(minLength: 0)
                        sortPicker
                    }
                }

                let groups = model.sortedGroups
                if layoutMode == .list {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            duplicateGroupBlock(group)
                            if group.id != groups.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                        ForEach(groups) { group in
                            duplicateGroupCard(group)
                        }
                    }
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $model.sortMode) {
            ForEach(DuplicateGroupSort.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help(Text("Sort"))
    }

    private var layoutPicker: some View {
        Picker(selection: Binding(
            get: { layoutMode },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    layoutMode = newValue
                }
            }
        )) {
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

    private func duplicateGroupBlock(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LumaL10n.format(
                    "%lld files · %@ wasted",
                    Int64(group.paths.count),
                    ByteFormatters.string(for: group.wastedBytes)
                ))
                .font(.subheadline.weight(.semibold))
                Spacer()
                Text(ByteFormatters.string(for: group.byteCount))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(group.hashHex)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            duplicatePathsSection(group)
        }
        .padding(.vertical, 6)
    }

    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumaTheme.storage.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundStyle(LumaTheme.storage)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatters.string(for: group.wastedBytes))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("reclaimable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(LumaL10n.format(
                "%lld files · %@ each",
                Int64(group.paths.count),
                ByteFormatters.string(for: group.byteCount)
            ))
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)

            Text(group.hashHex)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            duplicatePathsSection(group)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func duplicatePathsSection(_ group: DuplicateGroup) -> some View {
        let showAll = expandedGroups.contains(group.id)
        let visible = showAll ? group.paths : Array(group.paths.prefix(collapsedPathLimit))
        let hidden = group.paths.count - visible.count

        VStack(alignment: .leading, spacing: 6) {
            ForEach(visible, id: \.self) { path in
                duplicatePathRow(path)
            }

            if hidden > 0 {
                Button {
                    expandedGroups.insert(group.id)
                } label: {
                    Text(LumaL10n.format("Show %lld more", Int64(hidden)))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumaTheme.storage)
            } else if showAll, group.paths.count > collapsedPathLimit {
                Button {
                    expandedGroups.remove(group.id)
                } label: {
                    Text("Show less")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func duplicatePathRow(_ path: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .foregroundStyle(LumaTheme.storage)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text((path as NSString).lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(abbreviatedHomePath(path))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.borderless)
            .help(Text("Reveal in Finder"))
            Button("Trash", role: .destructive) {
                model.trash(path: path)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            Button("Move to Trash", role: .destructive) {
                model.trash(path: path)
            }
        }
    }

    private func abbreviatedHomePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
