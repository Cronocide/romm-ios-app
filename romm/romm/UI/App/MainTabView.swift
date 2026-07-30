//
//  MainTabView.swift
//  romm
//
//  Created by Ilyas Hallak on 08.08.25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appData: AppData
    private let dependencyFactory: PDependencyFactory
    
    init(dependencyFactory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.dependencyFactory = dependencyFactory
    }
    
    var body: some View {
        TabView(selection: $appData.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                PlatformsView()
            }
            .tabItem { Label("Platforms", systemImage: "gamecontroller") }
            .tag(AppTab.platforms)

            NavigationStack {
                CollectionView()
            }
            .tabItem { Label("Collections", systemImage: "books.vertical") }
            .tag(AppTab.collections)

            NavigationStack {
                LocalDeviceDetailView()
            }
            .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            .tag(AppTab.downloads)

            // Note: the iOS 18 `role: .search` treatment has no iOS 16
            // equivalent, so Search is an ordinary tab here.
            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)
        }
    }
}
