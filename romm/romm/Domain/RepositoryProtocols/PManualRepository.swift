//
//  PManualRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 13.08.25.
//

import Foundation

protocol PManualRepository {
    func loadManual(for romId: Int) async throws -> Manual?
    func getManualPDFData(for romId: Int) async throws -> Data?
}