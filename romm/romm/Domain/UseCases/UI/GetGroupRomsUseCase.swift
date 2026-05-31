//
//  GetGroupRomsUseCase.swift
//  romm
//

import Foundation

protocol PGetGroupRomsUseCase {
    func execute() -> Bool
}

class GetGroupRomsUseCase: PGetGroupRomsUseCase {

    static let storageKey = "groupRomsByMetaId"

    func execute() -> Bool {
        if let value = UserDefaults.standard.object(forKey: Self.storageKey) as? Bool {
            return value
        }
        return true
    }
}
