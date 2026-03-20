import Foundation
import Network

struct TCPPinger {

    /// TCPポート80への接続時間を計測する（応答時間の代替計測）
    /// - Returns: 応答時間(ms)、タイムアウト時はnil
    static func ping(host: String, port: UInt16 = 80, timeout: Double = 3.0) async -> Double? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            let start = Date()
            let lock = NSLock()
            var done = false

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
                    // ポートが閉じていてもホストが応答していれば成功とみなす
                    finish(Date().timeIntervalSince(start) * 1000)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(nil)
            }
        }
    }
}