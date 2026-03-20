import SwiftUI
import Network
import Foundation

// MARK: - Models

struct PingResult: Identifiable {
    let id = UUID()
    let seq: Int
    let host: String
    let responseTime: Double? // ms, nil = timeout
    let timestamp: Date

    var isSuccess: Bool { responseTime != nil }
    var displayTime: String {
        guard let t = responseTime else { return "タイムアウト" }
        return String(format: "%.1f ms", t)
    }
}

// MARK: - PingManager

@MainActor
class PingManager: ObservableObject {
    @Published var results: [PingResult] = []
    @Published var isRunning = false
    @Published var resolvedIP: String? = nil
    @Published var statusMessage: String = ""

    private var pingTask: Task<Void, Never>? = nil
    private var seq = 0

    func start(host: String, count: Int, interval: Double) {
        stop()
        results = []
        seq = 0
        resolvedIP = nil
        statusMessage = "解決中..."
        isRunning = true

        pingTask = Task {
            // Resolve host
            let resolved = await resolveHost(host)
            self.resolvedIP = resolved
            if resolved == nil {
                self.statusMessage = "ホスト解決失敗: \(host)"
                self.isRunning = false
                return
            }
            self.statusMessage = "\(host) (\(resolved!)) へPing送信中..."

            for i in 0..<count {
                guard !Task.isCancelled else { break }
                let s = self.seq
                self.seq += 1
                let t = await tcpPing(host: resolved!, port: 80, timeout: 3.0)
                let result = PingResult(seq: s + 1, host: resolved!, responseTime: t, timestamp: Date())
                self.results.append(result)

                if i < count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }

            let success = self.results.filter { $0.isSuccess }.count
            let total = self.results.count
            let avg = self.results.compactMap { $0.responseTime }.reduce(0, +) / Double(max(success, 1))
            self.statusMessage = "完了 — \(total)回送信, \(success)回成功, 平均 \(String(format: "%.1f", avg)) ms"
            self.isRunning = false
        }
    }

    func stop() {
        pingTask?.cancel()
        pingTask = nil
        isRunning = false
    }

    // TCP connect to measure round-trip
    private func tcpPing(host: String, port: UInt16, timeout: Double) async -> Double? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            let start = Date()
            var done = false
            let lock = NSLock()

            func finish(_ result: Double?) {
                lock.lock()
                defer { lock.unlock() }
                guard !done else { return }
                done = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(Date().timeIntervalSince(start) * 1000)
                case .failed:
                    finish(nil)
                case .waiting:
                    // port may be closed but host alive — count as success
                    finish(Date().timeIntervalSince(start) * 1000)
                default:
                    break
                }
            }
            connection.start(queue: .global())

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(nil)
            }
        }
    }

    // DNS resolution using URLSession
    private func resolveHost(_ host: String) async -> String? {
        // If already IP, return as-is
        if isIPAddress(host) { return host }
        // Use getaddrinfo via a simple TCP connection attempt just to resolve
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var hints = addrinfo()
                hints.ai_socktype = SOCK_STREAM
                var res: UnsafeMutablePointer<addrinfo>? = nil
                let status = getaddrinfo(host, nil, &hints, &res)
                defer { if res != nil { freeaddrinfo(res) } }
                guard status == 0, let info = res else {
                    continuation.resume(returning: nil)
                    return
                }
                var addr = info.pointee.ai_addr.pointee
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                if addr.sa_family == sa_family_t(AF_INET) {
                    var sin = withUnsafeBytes(of: &addr) { ptr in
                        ptr.load(as: sockaddr_in.self)
                    }
                    inet_ntop(AF_INET, &sin.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                } else {
                    var sin6 = withUnsafeBytes(of: &addr) { ptr in
                        ptr.load(as: sockaddr_in6.self)
                    }
                    inet_ntop(AF_INET6, &sin6.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
                }
                continuation.resume(returning: String(cString: buffer))
            }
        }
    }

    private func isIPAddress(_ s: String) -> Bool {
        var addr = in_addr()
        var addr6 = in6_addr()
        return inet_pton(AF_INET, s, &addr) == 1 || inet_pton(AF_INET6, s, &addr6) == 1
    }

    var stats: (sent: Int, received: Int, lost: Int, min: Double, max: Double, avg: Double) {
        let sent = results.count
        let times = results.compactMap { $0.responseTime }
        let received = times.count
        let lost = sent - received
        let mn = times.min() ?? 0
        let mx = times.max() ?? 0
        let avg = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
        return (sent, received, lost, mn, mx, avg)
    }
}

// MARK: - Main View

struct PingView: View {
    @StateObject private var manager = PingManager()
    @State private var host = "google.com"
    @State private var count = 10
    @State private var interval = 1.0
    @FocusState private var hostFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Config panel
                configPanel
                    .padding()
                    .background(Color(.systemGroupedBackground))

                // Status bar
                if !manager.statusMessage.isEmpty {
                    statusBar
                }

                // Results
                if !manager.results.isEmpty {
                    statsBar
                    resultList
                }

                Spacer()
            }
            .navigationTitle("Ping")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Config Panel

    var configPanel: some View {
        VStack(spacing: 12) {
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

            HStack(spacing: 16) {
                // Count stepper
                VStack(alignment: .leading, spacing: 4) {
                    Text("回数").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Button { if count > 1 { count -= 1 } } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.blue)
                        }
                        Text("\(count)").frame(width: 28).font(.headline)
                        Button { if count < 100 { count += 1 } } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                // Interval stepper
                VStack(alignment: .leading, spacing: 4) {
                    Text("間隔").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Button { if interval > 0.5 { interval -= 0.5 } } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.blue)
                        }
                        Text(String(format: "%.1fs", interval)).frame(width: 40).font(.headline)
                        Button { if interval < 5 { interval += 0.5 } } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: togglePing) {
                HStack {
                    Image(systemName: manager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    Text(manager.isRunning ? "停止" : "開始")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(manager.isRunning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Status Bar

    var statusBar: some View {
        HStack {
            if manager.isRunning {
                ProgressView().scaleEffect(0.8)
            }
            Text(manager.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: Stats Bar

    var statsBar: some View {
        let s = manager.stats
        return HStack(spacing: 0) {
            statCell(label: "送信", value: "\(s.sent)", color: .primary)
            statCell(label: "受信", value: "\(s.received)", color: .green)
            statCell(label: "損失", value: "\(s.lost)", color: s.lost > 0 ? .red : .secondary)
            statCell(label: "平均", value: s.received > 0 ? String(format: "%.0fms", s.avg) : "—", color: .blue)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Result List

    var resultList: some View {
        List(manager.results.reversed()) { result in
            HStack {
                // Indicator
                Circle()
                    .fill(result.isSuccess ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text("#\(result.seq)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)

                Text(result.host)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(result.displayTime)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(result.isSuccess ? responseColor(result.responseTime!) : .red)
                    .fontWeight(.medium)
            }
            .listRowBackground(Color(.systemBackground))
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: manager.results.count)
    }

    // MARK: Helpers

    func togglePing() {
        hostFocused = false
        if manager.isRunning {
            manager.stop()
        } else {
            manager.start(host: host.trimmingCharacters(in: .whitespaces), count: count, interval: interval)
        }
    }

    func responseColor(_ ms: Double) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .orange }
        return .red
    }
}

#Preview {
    PingView()
}
