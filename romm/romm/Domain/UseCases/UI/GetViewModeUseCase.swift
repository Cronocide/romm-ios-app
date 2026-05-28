//
//  GetViewModeUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 22.09.25.
//

import Foundation

protocol PGetViewModeUseCase {
    func execute() -> ViewMode
}

final class GetViewModeUseCase: PGetViewModeUseCase {
    private let repository: PViewModePreferenceRepository

    init(repository: PViewModePreferenceRepository) {
        self.repository = repository
    }

    func execute() -> ViewMode {
        repository.get()
    }
}
