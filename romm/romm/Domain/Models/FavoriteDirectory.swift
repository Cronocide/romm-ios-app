import Foundation

struct FavoriteDirectory: Identifiable, Codable, Equatable {
    let id: UUID
    let path: String
    let name: String
    let connectionId: UUID
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        path: String,
        name: String? = nil,
        connectionId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
        self.connectionId = connectionId
        self.createdAt = createdAt
    }
    
    var displayPath: String {
        return path.isEmpty ? "/" : path
    }
}

extension SFTPConnection {
    func credentials(from repository: PSFTPRepository) -> SFTPCredentials? {
        return repository.getCredentials(for: id)
    }
}

struct SFTPCredentials {
    let host: String
    let port: Int
    let username: String
    let authenticationType: AuthenticationType
    var password: String?
    var privateKey: String?
    var passphrase: String?
}