//
//  RomListComponents.swift
//  romm
//
//  Created by Ilyas Hallak on 10.08.25.
//

import SwiftUI

// MARK: - Header Component
struct RomListHeaderView: View {
    let title: String
    let iconName: String
    @Binding var viewMode: ViewMode
    let onFilter: (() -> Void)?
    
    init(title: String, iconName: String, viewMode: Binding<ViewMode>, onFilter: (() -> Void)? = nil) {
        self.title = title
        self.iconName = iconName
        self._viewMode = viewMode
        self.onFilter = onFilter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 40, height: 40)
            
            if let onFilter = onFilter {
                Button(action: onFilter) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch viewMode {
                    case .smallCard:
                        viewMode = .bigCard
                    case .bigCard:
                        viewMode = .table
                    case .table:
                        viewMode = .smallCard
                    }

                    // Save view mode preference asynchronously
                    let selectedMode = viewMode
                    Task.detached {
                        let asyncDefaults = AsyncUserDefaults.shared
                        await asyncDefaults.set(selectedMode.rawValue, forKey: "selectedViewMode")
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewMode.icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(viewMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Generic ROM List Container
struct GenericRomListView: View {
    let roms: [Rom]
    let viewMode: ViewMode
    let onRefresh: (() async -> Void)?
    let onLoadMore: (() async -> Void)?
    let onSort: ((String, String) async -> Void)?
    let currentOrderBy: String
    let currentOrderDir: String
    let canLoadMore: Bool
    let charIndex: [String: Int]
    let selectedChar: String?
    let onCharTapped: ((String?) async -> Void)?
    
    @State private var loadMoreTriggeredRoms: Set<Int> = []
    
    var body: some View {
        RomListWithSectionIndex(
            roms: roms,
            viewMode: viewMode,
            onRefresh: onRefresh,
            onLoadMore: onLoadMore,
            charIndex: charIndex,
            selectedChar: selectedChar,
            onCharTapped: onCharTapped,
            onSort: onSort,
            currentOrderBy: currentOrderBy,
            currentOrderDir: currentOrderDir,
            canLoadMore: canLoadMore,
            platform: nil
        )
    }
}

// MARK: - Empty State Component
struct EmptyRomListView: View {
    let title: String
    let message: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State Component
struct LoadingRomListView: View {
    let message: String
    
    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
