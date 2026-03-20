//
//  Untitled.swift
//  Ping
//
//  Created by 目時重孝 on 2026/03/20.
//

import Foundation

@MainActor
final class PingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var results: [PingResult] = []
    @Published var isRunning = false
    @Published var resolvedIP: String? = nil
    @Published var statusMessage: String = ""

    // MARK: - Private

    private var pingTask: Task<Void, Never>?
    private var seq = 0

    // MARK: - Public API

    func start(host: String, count: Int, interval: Double) {
        stop()
        results = []
        seq = 0
        resolvedIP = nil
        statusMessage = "解決中..."
        isRunning = true

        pingTask = Task {
            let trimmed = host.trimmingCharacters(in: .whitespaces)

            guard let ip = await HostResolver.resolve(trimmed) else {
                statusMessage = "ホスト解決失敗: \(trimmed)"
                isRunning = false
                return
            }

            resolvedIP = ip
            statusMessage = "\(trimmed) (\(ip)) へPing送信中..."

            for i in 0..<count {
                guard !Task.isCancelled else { break }

                let currentSeq = seq
                seq += 1

                let ms = await TCPPinger.ping(host: ip)
                let result = PingResult(seq: currentSeq + 1, host: ip, responseTime: ms, timestamp: Date())
                results.append(result)

                if i < count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }

            updateFinalStatus(host: trimmed)
            isRunning = false
        }
    }

    func stop() {
        pingTask?.cancel()
        pingTask = nil
        isRunning = false
    }

    // MARK: - Stats

    var stats: Stats {
        let times = results.compactMap { $0.responseTime }
        return Stats(
            sent: results.count,
            received: times.count,
            lost: results.count - times.count,
            min: times.min() ?? 0,
            max: times.max() ?? 0,
            avg: times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
        )
    }

    // MARK: - Private Helpers

    private func updateFinalStatus(host: String) {
        let s = stats
        let avgStr = String(format: "%.1f", s.avg)
        statusMessage = "完了 — \(s.sent)回送信, \(s.received)回成功, 平均 \(avgStr) ms"
    }

    // MARK: - Nested Types

    struct Stats {
        let sent: Int
        let received: Int
        let lost: Int
        let min: Double
        let max: Double
        let avg: Double
    }
}
