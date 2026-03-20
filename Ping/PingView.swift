//
//  PingView.swift
//  Ping
//
//  Created by 目時重孝 on 2026/03/20.
//

import SwiftUI

struct PingView: View {

    @StateObject private var viewModel = PingViewModel()

    @State private var host = "google.com"
    @State private var count = 10
    @State private var interval = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // 設定パネル
                ConfigPanelView(
                    host: $host,
                    count: $count,
                    interval: $interval,
                    isRunning: viewModel.isRunning,
                    onToggle: togglePing
                )
                .padding()
                .background(Color(.systemGroupedBackground))

                // ステータスバー
                if !viewModel.statusMessage.isEmpty {
                    StatusBarView(
                        message: viewModel.statusMessage,
                        isRunning: viewModel.isRunning
                    )
                }

                // 統計バー
                if !viewModel.results.isEmpty {
                    StatsBarView(stats: viewModel.stats)

                    // 結果リスト（新しい順）
                    List(viewModel.results.reversed()) { result in
                        ResultRowView(result: result)
                    }
                    .listStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.results.count)
                }

                Spacer()
            }
            .navigationTitle("Ping")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Private

    private func togglePing() {
        if viewModel.isRunning {
            viewModel.stop()
        } else {
            viewModel.start(host: host, count: count, interval: interval)
        }
    }
}

#Preview {
    PingView()
}
