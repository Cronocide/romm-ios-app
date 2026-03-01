//
//  FileSystemRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class FileSystemRepository: PFileSystemRepository {
    
    // MARK: - File Operations
    
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    func getFileSize(at path: String) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    func createDirectory(at path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    func deleteFile(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
    
    func moveFile(from source: String, to destination: String) throws {
        try FileManager.default.moveItem(atPath: source, toPath: destination)
    }
    
    func copyFile(from source: String, to destination: String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }
    
    // MARK: - Path Generation
    
    func temporaryDirectory() -> String {
        return FileManager.default.temporaryDirectory.path
    }
    
    func documentsDirectory() -> String {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    }
    
    func cachesDirectory() -> String {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""
    }
    
    func temporaryFilePath(for fileName: String) -> String {
        return temporaryDirectory().appending("/\(fileName)")
    }
    
    // MARK: - Storage Information
    
    func availableStorageCapacity() -> Int64? {
        do {
            let url = FileManager.default.temporaryDirectory
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = values.volumeAvailableCapacity {
                return Int64(capacity)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func formattedAvailableCapacity() -> String {
        guard let capacity = availableStorageCapacity() else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
    }
    
    func hasEnoughStorage(requiredBytes: Int64, safetyBufferPercent: Double = 0.2) -> Bool {
        guard let availableBytes = availableStorageCapacity() else { return true }
        let requiredBytesWithBuffer = Int64(Double(requiredBytes) * (1.0 + safetyBufferPercent))
        return availableBytes >= requiredBytesWithBuffer
    }
    
    // MARK: - File Information
    
    func fileAttributes(at path: String) throws -> [FileAttributeKey: Any] {
        return try FileManager.default.attributesOfItem(atPath: path)
    }
    
    func modificationDate(of path: String) throws -> Date? {
        let attributes = try fileAttributes(at: path)
        return attributes[.modificationDate] as? Date
    }
    
    func creationDate(of path: String) throws -> Date? {
        let attributes = try fileAttributes(at: path)
        return attributes[.creationDate] as? Date
    }
}