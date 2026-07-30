//
//  PlatformsViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

@MainActor
class PlatformsViewModel: ObservableObject {
    @Published var platforms: [Platform] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let getPlatformsUseCase: GetPlatformsUseCase
    private let addPlatformUseCase: AddPlatformUseCase
    
    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.getPlatformsUseCase = factory.makeGetPlatformsUseCase()
        self.addPlatformUseCase = factory.makeAddPlatformUseCase()

        // Don't load automatically - let view trigger via onAppear for better performance
        // This prevents blocking the main thread during ViewModel initialization
    }
    
    func loadPlatforms() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            try Task.checkCancellation()
            let platforms = try await getPlatformsUseCase.execute()
            try Task.checkCancellation()

            self.platforms = platforms
            self.isLoading = false
        } catch {
            if !Task.isCancelled {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func refreshPlatforms() async {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                try Task.checkCancellation()
                let platforms = try await getPlatformsUseCase.execute()
                try Task.checkCancellation()
                
                self.platforms = platforms
                isLoading = false
            } catch {
                if !Task.isCancelled {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func addPlatform(name: String, slug: String) {
        guard !name.isEmpty, !slug.isEmpty else {
            errorMessage = "Platform name and slug cannot be empty"
            return
        }
        
        Task {
            do {
                let newPlatform = try await addPlatformUseCase.execute(name: name, slug: slug)
                platforms.append(newPlatform)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func refresh() async {
        await refreshPlatforms()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
}
