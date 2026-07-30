//
//  VirtualCollectionDetailView.swift
//  romm
//
//  Created by Ilyas Hallak on 23.08.25.
//

import SwiftUI

struct VirtualCollectionDetailView: View {
    let virtualCollection: VirtualCollection
    @StateObject private var viewModel: VirtualCollectionDetailViewModel
    
    init(virtualCollection: VirtualCollection) {
        self.virtualCollection = virtualCollection
        self._viewModel = StateObject(wrappedValue: VirtualCollectionDetailViewModel(virtualCollectionId: virtualCollection.id))
    }
    
    var body: some View {
        VStack {
            switch viewModel.viewState {
            case .loading:
                ProgressView("Loading virtual collection...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .loaded:
                VStack {
                    Text("Virtual Collection Detail")
                        .font(.title)
                    Text(virtualCollection.name)
                        .font(.headline)
                    Text("Virtual collections coming soon...")
                        .foregroundColor(.secondary)
                    Text("Collection ID: \(virtualCollection.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
            case .error:
                Color(.systemGroupedBackground).ignoresSafeArea()
            }
        }
        .navigationTitle(virtualCollection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadVirtualCollection()
        }
        .alert("Error", isPresented: Binding(
            get: { if case .error = viewModel.viewState { return true }; return false },
            set: { if !$0 { viewModel.dismissError() } }
        ), actions: {
            Button("Retry") {
                Task { await viewModel.loadVirtualCollection() }
            }
            Button("Dismiss", role: .cancel) { }
        }, message: {
            if case .error(let msg) = viewModel.viewState { Text(msg) }
        })
    }
}