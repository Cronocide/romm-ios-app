//
//  SaveViewModeUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 22.09.25.
//

import Foundation

protocol PSaveViewModeUseCase {
    func execute(_ viewMode: ViewMode)
}

final class SaveViewModeUseCase: PSaveViewModeUseCase {
    private let repository: PViewModePreferenceRepository

    init(repository: PViewModePreferenceRepository) {
        self.repository = repository
    }

    func execute(_ viewMode: ViewMode) {
        repository.set(viewMode)
    }
}
