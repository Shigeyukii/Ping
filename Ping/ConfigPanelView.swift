import SwiftUI

struct ConfigPanelView: View {

    @Binding var host: String
    @Binding var count: Int
    @Binding var interval: Double
    let isRunning: Bool
    let onToggle: () -> Void

    @FocusState private var hostFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // ホスト入力
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundColor(.secondary)
                TextField("ホスト名 または IP", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($hostFocused)
                    .submitLabel(.done)
                    .onSubmit { hostFocused = false }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 回数・間隔ステッパー
            HStack(spacing: 16) {
                StepperCell(
                    label: "回数",
                    value: "\(count)",
                    onDecrement: { if count > 1 { count -= 1 } },
                    onIncrement: { if count < 100 { count += 1 } }
                )

                Divider().frame(height: 40)

                StepperCell(
                    label: "間隔",
                    value: String(format: "%.1fs", interval),
                    onDecrement: { if interval > 0.5 { interval -= 0.5 } },
                    onIncrement: { if interval < 5 { interval += 0.5 } }
                )
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 開始/停止ボタン
            Button(action: {
                hostFocused = false
                onToggle()
            }) {
                HStack {
                    Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    Text(isRunning ? "停止" : "開始")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isRunning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - StepperCell

private struct StepperCell: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.blue)
                }
                Text(value)
                    .frame(width: 44)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}