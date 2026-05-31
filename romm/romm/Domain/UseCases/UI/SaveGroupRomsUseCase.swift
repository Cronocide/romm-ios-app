//
//  SaveGroupRomsUseCase.swift
//  romm
//

import Foundation

protocol PSaveGroupRomsUseCase {
    func execute(_ enabled: Bool)
}

class SaveGroupRomsUseCase: PSaveGroupRomsUseCase {

    func execute(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: GetGroupRomsUseCase.storageKey)
    }
}
