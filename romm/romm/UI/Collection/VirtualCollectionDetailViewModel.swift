//
//  VirtualCollectionDetailViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 23.08.25.
//

import Foundation
import Observation

@Observable
@MainActor
class VirtualCollectionDetailViewModel {
    private let logger = Logger.viewModel
    var viewState: ViewState = .loading
    
    private var virtualCollectionId: String
    
    enum ViewState {
        case loading
        case loaded
        case error(String)
    }
    
    init(virtualCollectionId: String) {
        self.virtualCollectionId = virtualCollectionId
    }
    
    func dismissError() {
        viewState = .loaded
    }

    func loadVirtualCollection() async {
        viewState = .loading
        
        // TODO: Implement actual virtual collection loading logic
        // For now, just simulate loading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        viewState = .loaded
        logger.info("Virtual collection \(virtualCollectionId) loaded")
    }
}