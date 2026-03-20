//
//  ResultRowView.swift
//  Ping
//
//  Created by 目時重孝 on 2026/03/20.
//


import SwiftUI

struct ResultRowView: View {
    let result: PingResult

    var body: some View {
        HStack {
            // 成功/失敗インジケーター
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
                .fontWeight(.medium)
                .foregroundColor(responseColor)
        }
        .listRowBackground(Color(.systemBackground))
    }

    // MARK: - Private

    private var responseColor: Color {
        guard let ms = result.responseTime else { return .red }
        if ms < 50  { return .green }
        if ms < 150 { return .orange }
        return .red
    }
}