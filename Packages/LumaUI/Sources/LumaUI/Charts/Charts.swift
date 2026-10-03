import Charts
import SwiftUI
import LumaCore

public struct CategoryBytesChart: View {
    public struct Slice: Identifiable {
        public var id: String { label }
        public var label: String
        public var bytes: UInt64

        public init(label: String, bytes: UInt64) {
            self.label = label
            self.bytes = bytes
        }
    }

    private let slices: [Slice]

    public init(slices: [Slice]) {
        self.slices = slices
    }

    public var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Bytes", slice.bytes),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Category", slice.label))
        }
        .chartLegend(position: .bottom, spacing: 8)
        .frame(minHeight: 220)
        .accessibilityLabel("Storage category chart")
    }
}

public struct SparklineChart: View {
    private let values: [Double]
    private let tint: Color

    public init(values: [Double], tint: Color = .accentColor) {
        self.values = values
        self.tint = tint
    }

    public var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            LineMark(
                x: .value("t", item.offset),
                y: .value("v", item.element)
            )
            .foregroundStyle(tint)
            AreaMark(
                x: .value("t", item.offset),
                y: .value("v", item.element)
            )
            .foregroundStyle(tint.opacity(0.15))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .frame(height: 36)
        .accessibilityHidden(true)
    }
}
