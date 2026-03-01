//
//  StatsViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 16.11.25.
//

import Foundation
import Observation

enum StatsSortOrder: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case romCount = "ROM Count"
}

struct PlatformStats: Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String
    let manufacturer: String
    let romCount: Int
    let sizeBytes: Int
    let percentage: Double
    let logoPath: String?
}

@Observable
@MainActor
class StatsViewModel {
    var stats: Stats?
    var platforms: [Platform] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var sortOrder: StatsSortOrder = .name

    private let getStatsUseCase: GetStatsUseCase
    private let getPlatformsUseCase: GetPlatformsUseCase

    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.getStatsUseCase = factory.makeGetStatsUseCase()
        self.getPlatformsUseCase = factory.makeGetPlatformsUseCase()
    }

    var platformStats: [PlatformStats] {
        guard let stats = stats, stats.totalFilesizeBytes > 0 else {
            return []
        }

        let platformsWithStats = platforms.map { platform in
            let sizeBytes = platform.sizeBytes
            let percentage = Double(sizeBytes) / Double(stats.totalFilesizeBytes) * 100.0

            return PlatformStats(
                id: platform.id,
                name: platform.name,
                slug: platform.slug,
                manufacturer: platform.manufacturer ?? "Unknown",
                romCount: platform.romCount,
                sizeBytes: sizeBytes,
                percentage: percentage,
                logoPath: platform.logoPath
            )
        }

        // Sort based on selected order
        switch sortOrder {
        case .name:
            return platformsWithStats.sorted { $0.name < $1.name }
        case .size:
            return platformsWithStats.sorted { $0.sizeBytes > $1.sizeBytes }
        case .romCount:
            return platformsWithStats.sorted { $0.romCount > $1.romCount }
        }
    }

    func loadData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            try Task.checkCancellation()

            // Load stats and platforms in parallel
            async let statsResult = getStatsUseCase.execute()
            async let platformsResult = getPlatformsUseCase.execute()

            let (loadedStats, loadedPlatforms) = try await (statsResult, platformsResult)

            try Task.checkCancellation()

            self.stats = loadedStats
            self.platforms = loadedPlatforms
            self.isLoading = false
        } catch {
            if !Task.isCancelled {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }

        Task {
            await loadData()
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
