import SwiftUI

struct StatusBarView: View {
    let message: String
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.8)
            }
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
    }
}