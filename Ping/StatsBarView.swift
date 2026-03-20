import SwiftUI

struct StatsBarView: View {
    let stats: PingViewModel.Stats

    var body: some View {
        HStack(spacing: 0) {
            StatCell(label: "送信", value: "\(stats.sent)",     color: .primary)
            StatCell(label: "受信", value: "\(stats.received)", color: .green)
            StatCell(label: "損失", value: "\(stats.lost)",     color: stats.lost > 0 ? .red : .secondary)
            StatCell(label: "平均", value: avgText,             color: .blue)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var avgText: String {
        stats.received > 0 ? String(format: "%.0fms", stats.avg) : "—"
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}