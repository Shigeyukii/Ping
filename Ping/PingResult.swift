//
//  PingResult.swift
//  Ping
//
//  Created by 目時重孝 on 2026/03/20.
//

import Foundation

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
