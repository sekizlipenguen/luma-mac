import SwiftUI
import LumaCore

public enum LumaTheme {
    public static let cardCornerRadius: CGFloat = 14
    public static let metricsSpacing: CGFloat = 12

    public static let cpu = Color(red: 0.20, green: 0.55, blue: 0.95)
    public static let memory = Color(red: 0.45, green: 0.55, blue: 0.95)
    public static let storage = Color(red: 0.15, green: 0.72, blue: 0.62)
    public static let network = Color(red: 0.35, green: 0.70, blue: 0.45)
    public static let battery = Color(red: 0.95, green: 0.68, blue: 0.22)
    public static let thermal = Color(red: 0.92, green: 0.42, blue: 0.35)
}

public struct MetricCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var accent: Color
    let content: Content

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        accent: Color = .secondary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}

public struct ProgressMetricView: View {
    let value: Double
    let label: String
    let tint: Color

    public init(value: Double, label: String, tint: Color = .accentColor) {
        self.value = value
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        let progress = value.isFinite ? min(max(value, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.title2.monospacedDigit().weight(.semibold))
            ProgressView(value: progress)
                .tint(tint)
                .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

public struct ProcessRow: View {
    let name: String
    let value: String
    var bar: Double?

    public init(name: String, value: String, bar: Double? = nil) {
        self.name = name
        self.value = value
        self.bar = bar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .font(.callout)
            }
            if let bar {
                let progress = bar.isFinite ? min(max(bar, 0), 1) : 0
                ProgressView(value: progress)
                    .tint(.secondary.opacity(0.55))
                    .controlSize(.mini)
            }
        }
    }
}

public struct UnavailableStateView: View {
    let title: LocalizedStringKey
    let reason: LocalizedStringKey

    public init(title: LocalizedStringKey, reason: LocalizedStringKey) {
        self.title = title
        self.reason = reason
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(reason)
        }
    }
}

public struct EmptyScanView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } actions: {
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
    }
}
