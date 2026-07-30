//
//  CollectionPickerView.swift
//  romm
//
//  Created by Ilyas Hallak on 28.08.25.
//

import SwiftUI

struct CollectionPickerView: View {
    let rom: Rom
    @Binding var isPresented: Bool
    let onCollectionChanged: (() -> Void)?
    @StateObject private var viewModel = CollectionPickerViewModel()
    @State private var hasChanges = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoadingCollections {
                    ProgressView("Loading collections...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.availableCollections.isEmpty {
                    emptyStateView
                } else {
                    collectionsList
                }
            }
            .navigationTitle("Manage Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if hasChanges {
                            onCollectionChanged?()
                        }
                        isPresented = false
                    }
                }
            }
            .toast(
                isPresented: $viewModel.showSuccessToast,
                message: viewModel.successMessage ?? "",
                type: .success,
                duration: 2.0
            )
            .toast(
                isPresented: $viewModel.showErrorToast,
                message: viewModel.errorMessage ?? "",
                type: .error,
                duration: 3.0
            )
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.showErrorToast)) {
                Button("OK") {
                    viewModel.clearMessages()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.loadCollections()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No collections available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create collections from the main menu to organize your ROMs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var collectionsList: some View {
        List(viewModel.availableCollections) { collection in
            let isRomInCollection = viewModel.isRomInCollection(romId: rom.id, collection: collection)
            
            Button(action: {
                Task {
                    let success = await viewModel.toggleRomInCollection(romId: rom.id, collection: collection)
                    if success {
                        hasChanges = true
                        // Success toast will show, but view stays open for multiple edits
                    }
                }
            }) {
                HStack {
                    CollectionRowView(collection: collection)
                    
                    Spacer()
                    
                    if isRomInCollection {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .background(isRomInCollection ? Color.green.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
    }
}

#Preview {
    CollectionPickerView(
        rom: Rom(
            id: 1,
            name: "Test ROM",
            platformId: 1,
            urlCover: nil,
            isFavourite: false,
            hasRetroAchievements: false,
            isPlayable: true
        ),
        isPresented: .constant(true),
        onCollectionChanged: nil
    )
}
