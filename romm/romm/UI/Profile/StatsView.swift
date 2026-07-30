//
//  StatsView.swift
//  romm
//
//  Created by Ilyas Hallak on 16.11.25.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var statsViewModel = StatsViewModel()

    var body: some View {
        Group {
            if statsViewModel.isLoading && statsViewModel.stats == nil {
                LoadingView("Loading Statistics...", fillScreen: true)
            } else if let stats = statsViewModel.stats {
                statsContentView(stats: stats)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Statistics")
        .onAppear {
            if statsViewModel.stats == nil && !statsViewModel.isLoading {
                Task {
                    await statsViewModel.loadData()
                }
            }
        }
        .refreshable {
            await statsViewModel.refresh()
        }
        .alert("Error", isPresented: .constant(statsViewModel.errorMessage != nil)) {
            Button("Retry") {
                Task {
                    await statsViewModel.refresh()
                }
                statsViewModel.clearError()
            }
            Button("OK") {
                statsViewModel.clearError()
            }
        } message: {
            Text(statsViewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func statsContentView(stats: Stats) -> some View {
        List {
            Section {
                statsGridSection(stats: stats)
            } header: {
                Text("Overview")
                    .font(.headline)
            }

            Section {
                sortOrderPicker

                ForEach(statsViewModel.platformStats) { platformStat in
                    PlatformStatsRowView(platformStats: platformStat)
                }
            } header: {
                HStack {
                    Image(systemName: "externaldrive")
                    Text("Size per Platform")
                }
                .font(.headline)
            }
        }
    }

    @ViewBuilder
    private func statsGridSection(stats: Stats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCardView(
                    icon: "gamecontroller.fill",
                    value: "\(stats.platforms)",
                    label: "Platforms"
                )

                StatCardView(
                    icon: "opticaldisc",
                    value: "\(stats.roms)",
                    label: "Games"
                )
            }

            HStack(spacing: 12) {
                StatCardView(
                    icon: "opticaldiscdrive",
                    value: "\(stats.saves)",
                    label: "Saves"
                )

                StatCardView(
                    icon: "doc.fill",
                    value: "\(stats.states)",
                    label: "States"
                )
            }

            HStack(spacing: 12) {
                StatCardView(
                    icon: "photo.fill",
                    value: "\(stats.screenshots)",
                    label: "Screenshots"
                )

                StatCardView(
                    icon: "externaldrive.fill",
                    value: ByteFormatter.format(stats.totalFilesizeBytes),
                    label: "Size on Disk"
                )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var sortOrderPicker: some View {
        Picker("Order by", selection: $statsViewModel.sortOrder) {
            ForEach(StatsSortOrder.allCases, id: \.self) { order in
                Text(order.rawValue).tag(order)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Statistics could not be loaded")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
}
