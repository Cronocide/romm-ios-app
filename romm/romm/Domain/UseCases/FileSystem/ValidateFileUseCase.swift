//
//  ValidateFileUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class ValidateFileUseCase {
    private let fileValidationService: PFileValidationService
    
    init(fileValidationService: PFileValidationService) {
        self.fileValidationService = fileValidationService
    }
    
    func execute(at path: String, expectedSize: Int64? = nil, expectedChecksum: String? = nil) -> FileValidationResult {
        return fileValidationService.validateFile(at: path, expectedSize: expectedSize, expectedChecksum: expectedChecksum)
    }
    
    func calculateChecksum(at path: String) throws -> String {
        return try fileValidationService.calculateChecksum(at: path)
    }
    
    func validateIntegrity(at path: String, expectedSize: Int64? = nil, expectedChecksum: String? = nil) throws {
        let result = execute(at: path, expectedSize: expectedSize, expectedChecksum: expectedChecksum)
        
        if !result.isValid {
            throw SFTPError.fileValidationFailed(result.errorMessage ?? "Unknown validation error")
        }
    }
}