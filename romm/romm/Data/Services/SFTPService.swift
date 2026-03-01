import Foundation
import mft

struct SFTPServiceItem {
    let filename: String
    let size: UInt64
    let uid: UInt32
    let createTime: Date
    let isDirectory: Bool
    let isSymlink: Bool
}

class MFTSftpConnectionFacade {
    let hostname: String
    let port: Int32
    let username: String
    let password: String
    
    private let mft: MFTSftpConnection
    
    
    init(hostname: String, port: Int32, username: String, password: String) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        
        self.mft = .init(hostname: hostname, port: Int(port), username: username, password: password)
    }
    
    func connect() throws {
        do {
            try mft.connect()
        } catch {
            throw SFTPError.connectionFailed
        }
    }
    
    func authenticate() throws {
        do {
            try mft.authenticate()
        } catch {
            throw SFTPError.authenticationFailed
        }
    }
    
    func disconnect() {
        mft.disconnect()
    }
    
    func contentsOfDirectory(atPath path: String, maxItems: Int) throws -> [SFTPDirectoryItem] {
        do {
            let result = try mft.contentsOfDirectory(atPath: path, maxItems: Int64(maxItems))
            
            // Safety check - ensure result is actually an array
            guard let directoryContents = result as? [Any] else {
                print("🔍 SFTP Directory: Invalid result type from mft.contentsOfDirectory: \(type(of: result))")
                throw SFTPError.pathNotFound
            }
            
            return directoryContents.compactMap { item -> SFTPDirectoryItem? in
                // The mft library returns MFTSftpItem objects, we need to use KVC to access properties
                print("🔍 SFTP Directory: Processing item of type: \(type(of: item))")
                
                // Try to extract properties using key-value coding since it's an MFTSftpItem
                guard let fileName = (item as AnyObject).value(forKey: "filename") as? String else {
                    print("🔍 SFTP Directory: Could not get filename from item")
                    return nil
                }
                
                let isDir = ((item as AnyObject).value(forKey: "isDirectory") as? Bool) ?? false
                let fileSize = ((item as AnyObject).value(forKey: "size") as? UInt64) ?? 0
                let createTime = ((item as AnyObject).value(forKey: "createTime") as? Date) ?? Date()
                
                // Build the full path like in the original working version  
                let fullPath = path.hasSuffix("/") ? "\(path)\(fileName)" : "\(path)/\(fileName)"
                
                print("🔍 SFTP Directory: Created item - name: \(fileName), path: \(fullPath), isDir: \(isDir)")
                
                return SFTPDirectoryItem(
                    name: fileName, 
                    path: fullPath, 
                    isDirectory: isDir, 
                    size: Int64(fileSize), 
                    modificationDate: createTime
                )
            }
        } catch {
            print("🔍 SFTP Directory error: \(error)")
            throw SFTPError.pathNotFound
        }
    }
    
    func upload(localFilePath: String, toPath remotePath: String, progress: @escaping (UInt64) -> Bool) throws {
        do {
            try mft.uploadFile(atPath: localFilePath, toFileAtPath: remotePath, progress: progress)
        } catch {
            print("🔍 MFT Upload: Error occurred: \(error)")
            // Don't automatically throw - the upload might have succeeded despite the error
            // Let the calling code handle success/failure based on progress completion
            throw SFTPError.uploadFailed
        }
    }
    
    func write(stream: InputStream, toFileAtPath path: String, append: Bool, progress: @escaping (UInt64) -> Bool) throws {
        do {
            try mft.write(stream: stream, toFileAtPath: path, append: append, progress: progress)
        } catch {
            throw SFTPError.uploadFailed
        }
    }
    
    func read(fromFileAtPath path: String, toStream: OutputStream, progress: @escaping (Int) -> Bool) throws {
        throw SFTPError.downloadFailed
    }
    
    func createDirectory(atPath path: String) throws {
        do {
            try mft.createDirectory(atPath: path)
        } catch {
            throw SFTPError.pathNotFound
        }
    }
    
    func removeFile(atPath path: String) throws {
        do {
            try mft.createDirectory(atPath: path)
        } catch {
            throw SFTPError.pathNotFound
        }
    }
}

enum SFTPError: LocalizedError {
    case connectionFailed
    case authenticationFailed
    case pathNotFound
    case uploadFailed
    case downloadFailed
    case connectionTimeout
    case invalidCredentials
    case networkError(String)
    case insufficientStorage(required: Int64, available: Int64)
    case serviceNotConfigured
    case fileValidationFailed(String)
    case incompleteDownload(actual: Int64, expected: Int64)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to SFTP server"
        case .authenticationFailed:
            return "Authentication failed"
        case .pathNotFound:
            return "Path not found on server"
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        case .connectionTimeout:
            return "Connection timeout"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError(let message):
            return "Network error: \(message)"
        case .insufficientStorage(let required, let available):
            let requiredStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availableStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Not enough storage space. Required: \(requiredStr), Available: \(availableStr)"
        case .serviceNotConfigured:
            return "SFTP service not configured"
        case .fileValidationFailed(let message):
            return "File validation failed: \(message)"
        case .incompleteDownload(let actual, let expected):
            let actualStr = ByteCountFormatter.string(fromByteCount: actual, countStyle: .file)
            let expectedStr = ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)
            return "Incomplete download: got \(actualStr), expected \(expectedStr)"
        }
    }
}

struct SFTPDirectoryItem: Identifiable {
    let id: UUID = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?
}

protocol PSFTPService {
    func testConnection(_ connection: SFTPConnection) async throws -> Bool
    func testConnectionWithCredentials(_ connection: SFTPConnection, credentials: SFTPCredentials) async throws -> Bool
    func listDirectory(at path: String, connection: SFTPConnection) async throws -> [SFTPDirectoryItem]
    func uploadFile(from localPath: String, to remotePath: String, connection: SFTPConnection, progressHandler: @escaping @Sendable @MainActor (Int64, Int64) -> Void) async throws
    func downloadFile(from remotePath: String, to localPath: String, connection: SFTPConnection, progressHandler: @escaping @Sendable @MainActor (Int64, Int64) -> Void) async throws
    func createDirectory(at path: String, connection: SFTPConnection) async throws
    func deleteFile(at path: String, connection: SFTPConnection) async throws
}

class SFTPService: PSFTPService {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository = SFTPRepository()) {
        self.repository = repository
    }
    
    private func createConnection(_ connection: SFTPConnection, with credentials: SFTPCredentials? = nil) -> MFTSftpConnectionFacade {
        let creds = credentials ?? repository.getCredentials(for: connection.id)
        
        return MFTSftpConnectionFacade(
            hostname: connection.host,
            port: Int32(connection.port),
            username: connection.username,
            password: creds?.password ?? ""
        )
    }
    
    private func authenticateConnection(_ sftp: MFTSftpConnectionFacade, connection: SFTPConnection, credentials: SFTPCredentials? = nil) throws {
        let creds = credentials ?? repository.getCredentials(for: connection.id)
        
        switch connection.authenticationType {
        case .password:
            guard let creds = creds, let password = creds.password, !password.isEmpty else {
                throw SFTPError.invalidCredentials
            }
            try sftp.authenticate()
            
        case .sshKey:
            guard let creds = creds, let privateKey = creds.privateKey, !privateKey.isEmpty else {
                throw SFTPError.invalidCredentials
            }
            // For SSH key authentication, we would need to implement key-based auth
            // This is a placeholder for the actual implementation
            throw SFTPError.authenticationFailed
            
        case .passwordWithKey:
            guard let creds = creds, 
                  let password = creds.password, !password.isEmpty,
                  let privateKey = creds.privateKey, !privateKey.isEmpty else {
                throw SFTPError.invalidCredentials
            }
            // For combined auth, we would need to implement both
            // This is a placeholder for the actual implementation
            throw SFTPError.authenticationFailed
        }
    }
    
    // OPTIMIZED: MFT completely isolated in background thread with hard timeout
    func testConnection(_ connection: SFTPConnection) async throws -> Bool {
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            // Task 1: Actual connection test in dedicated background queue
            // This ensures MFT's blocking socket operations don't block Swift Concurrency threads
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    // Use DispatchQueue instead of Task.detached for complete isolation
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self else {
                            continuation.resume(returning: false)
                            return
                        }

                        do {
                            let sftp = self.createConnection(connection)
                            defer { sftp.disconnect() }

                            // MFT's blocking calls run in isolated background thread
                            try sftp.connect()
                            try self.authenticateConnection(sftp, connection: connection)

                            continuation.resume(returning: true)
                        } catch {
                            continuation.resume(throwing: self.mapMFTError(error))
                        }
                    }
                }
            }

            // Task 2: Hard timeout (3 seconds)
            // This ensures UI responsiveness even if MFT hangs
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                throw SFTPError.connectionTimeout
            }

            // Race: First to complete wins
            guard let result = try await group.next() else {
                throw SFTPError.connectionTimeout
            }

            // Cancel the other task (either timeout or connection test)
            group.cancelAll()
            return result
        }
    }
    
    func testConnectionWithCredentials(_ connection: SFTPConnection, credentials: SFTPCredentials) async throws -> Bool {
        // Same isolation strategy as testConnection for consistency
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            // Task 1: Connection test in background queue
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self else {
                            continuation.resume(returning: false)
                            return
                        }

                        do {
                            let sftp = self.createConnection(connection, with: credentials)
                            defer { sftp.disconnect() }

                            try sftp.connect()
                            try self.authenticateConnection(sftp, connection: connection, credentials: credentials)

                            continuation.resume(returning: true)
                        } catch {
                            continuation.resume(throwing: self.mapMFTError(error))
                        }
                    }
                }
            }

            // Task 2: Hard timeout (3 seconds)
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                throw SFTPError.connectionTimeout
            }

            guard let result = try await group.next() else {
                throw SFTPError.connectionTimeout
            }

            group.cancelAll()
            return result
        }
    }
    
    func listDirectory(at path: String, connection: SFTPConnection) async throws -> [SFTPDirectoryItem] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let sftp = createConnection(connection)
                    
                    try sftp.connect()
                    defer { sftp.disconnect() }
                    
                    try sftp.authenticate()
                    
                    print("🔍 SFTP Service: About to call contentsOfDirectory for path: \(path)")
                    let contents = try sftp.contentsOfDirectory(atPath: path, maxItems: 1000)
                    print("🔍 SFTP Service: Raw contents type: \(type(of: contents))")
                    
                    // Safety check - the count call was causing NSNumber crashes
                    if let contentsArray = contents as? [Any] {
                        print("🔍 SFTP Service: Got \(contentsArray.count) items from directory listing")
                    } else {
                        print("🔍 SFTP Service: WARNING - contents is not an array but: \(type(of: contents))")
                        print("🔍 SFTP Service: contents value: \(contents)")
                    }
                    
                    let items = contents.compactMap { item -> SFTPDirectoryItem? in
                        let fullPath = path.hasSuffix("/") ? "\(path)\(item.name)" : "\(path)/\(item.name)"
                        
                        return SFTPDirectoryItem(
                            name: item.name,
                            path: fullPath,
                            isDirectory: item.isDirectory,
                            size: item.size,
                            modificationDate: item.modificationDate
                        )
                    }
                    
                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(throwing: mapMFTError(error))
                }
            }
        }
    }
    
    func uploadFile(from localPath: String, to remotePath: String, connection: SFTPConnection, progressHandler: @escaping @Sendable @MainActor (Int64, Int64) -> Void) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let sftp = createConnection(connection)
                    
                    try sftp.connect()
                    defer { sftp.disconnect() }
                    
                    try sftp.authenticate()
                    
                    guard let inputStream = InputStream(fileAtPath: localPath) else {
                        throw SFTPError.uploadFailed
                    }
                    
                    let fileManager = FileManager.default
                    let fileAttributes = try fileManager.attributesOfItem(atPath: localPath)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    
                    var uploadedBytes: Int64 = 0
                    var uploadCompleted = false
                    
                    print("🔍 SFTP Upload: Starting upload of file size: \(fileSize) bytes")
                    
                    do {
                        try sftp.upload(localFilePath: localPath, toPath: remotePath) { bytesWritten in
                            // Stop processing if upload is already marked as completed
                            guard !uploadCompleted else {
                                print("🔍 SFTP Upload: Ignoring progress update - upload completed")
                                return false // Signal to stop progress callbacks
                            }
                            
                            // CRITICAL FIX: bytesWritten from mft library is total bytes uploaded so far, not delta
                            // Don't accumulate - use the value directly
                            let totalBytesWritten = Int64(bytesWritten)
                            
                            // Debug the raw values from mft library
                            print("🔍 SFTP Upload: mft reported totalBytesWritten=\(bytesWritten) (UInt64), fileSize=\(fileSize)")
                            
                            // Ensure uploaded bytes don't exceed file size
                            let clampedUploaded = min(totalBytesWritten, fileSize)
                            
                            // Check if upload is complete (with small tolerance for rounding errors)
                            if clampedUploaded >= fileSize || Double(clampedUploaded) / Double(fileSize) >= 0.999 {
                                uploadCompleted = true
                                print("🔍 SFTP Upload: Upload completed, stopping progress updates")
                            }
                            
                            DispatchQueue.main.async {
                                progressHandler(clampedUploaded, fileSize)
                            }
                            
                            // Return false to stop progress callbacks if completed
                            return !uploadCompleted
                        }
                        
                        print("🔍 SFTP Upload: mft.upload completed successfully")
                        
                    } catch {
                        print("🔍 SFTP Upload: mft.upload threw error: \(error)")
                        
                        // Check if upload actually completed despite the error
                        if uploadCompleted {
                            print("🔍 SFTP Upload: Upload was completed successfully despite mft error")
                        } else {
                            print("🔍 SFTP Upload: Upload failed - progress never reached 100%")
                            throw mapMFTError(error)
                        }
                    }
                    
                    // Ensure final 100% progress is shown
                    print("🔍 SFTP Upload: Upload completed - ensuring 100% progress")
                    DispatchQueue.main.async {
                        progressHandler(fileSize, fileSize) // Force 100%
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func downloadFile(from remotePath: String, to localPath: String, connection: SFTPConnection, progressHandler: @escaping @Sendable @MainActor (Int64, Int64) -> Void) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let sftp = createConnection(connection)
                    
                    try sftp.connect()
                    defer { sftp.disconnect() }
                    
                    try sftp.authenticate()
                    
                    guard let outputStream = OutputStream(toFileAtPath: localPath, append: false) else {
                        throw SFTPError.downloadFailed
                    }
                    
                    var downloadedBytes: Int64 = 0
                    let fileSize: Int64 = 0
                    
                    try sftp.read(fromFileAtPath: remotePath, toStream: outputStream) { bytesRead in
                        downloadedBytes += Int64(bytesRead)
                        DispatchQueue.main.async {
                            progressHandler(downloadedBytes, fileSize)
                        }
                        return true
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: mapMFTError(error))
                }
            }
        }
    }
    
    func createDirectory(at path: String, connection: SFTPConnection) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let sftp = createConnection(connection)
                    
                    try sftp.connect()
                    defer { sftp.disconnect() }
                    
                    try sftp.authenticate()
                    
                    try sftp.createDirectory(atPath: path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: mapMFTError(error))
                }
            }
        }
    }
    
    func deleteFile(at path: String, connection: SFTPConnection) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let sftp = createConnection(connection)
                    
                    try sftp.connect()
                    defer { sftp.disconnect() }
                    
                    try sftp.authenticate()
                    
                    try sftp.removeFile(atPath: path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: mapMFTError(error))
                }
            }
        }
    }
    
    private func mapMFTError(_ error: Error) -> SFTPError {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("connect") || errorString.contains("connection") {
            return .connectionFailed
        } else if errorString.contains("auth") {
            return .authenticationFailed
        } else if errorString.contains("timeout") {
            return .connectionTimeout
        } else if errorString.contains("path") || errorString.contains("directory") {
            return .pathNotFound
        } else {
            return .networkError(error.localizedDescription)
        }
    }
}
