//
//  PFileSystemRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

protocol PFileSystemRepository {
    // MARK: - File Operations
    func fileExists(at path: String) -> Bool
    func getFileSize(at path: String) throws -> Int64
    func createDirectory(at path: String) throws
    func deleteFile(at path: String) throws
    func moveFile(from source: String, to destination: String) throws
    func copyFile(from source: String, to destination: String) throws
    
    // MARK: - Path Generation
    func temporaryDirectory() -> String
    func documentsDirectory() -> String
    func cachesDirectory() -> String
    func temporaryFilePath(for fileName: String) -> String
    
    // MARK: - Storage Information
    func availableStorageCapacity() -> Int64?
    func formattedAvailableCapacity() -> String
    func hasEnoughStorage(requiredBytes: Int64, safetyBufferPercent: Double) -> Bool
    
    // MARK: - File Information
    func fileAttributes(at path: String) throws -> [FileAttributeKey: Any]
    func modificationDate(of path: String) throws -> Date?
    func creationDate(of path: String) throws -> Date?
}