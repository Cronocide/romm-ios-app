import Foundation

enum AuthenticationType: String, CaseIterable, Codable {
    case password = "password"
    case sshKey = "ssh_key"
    case passwordWithKey = "password_with_key"
    
    var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .sshKey:
            return "SSH Key"
        case .passwordWithKey:
            return "Password + SSH Key"
        }
    }
}

enum ConnectionStatus: String, CaseIterable, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case authenticating = "authenticating"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .authenticating:
            return "Authenticating..."
        case .error:
            return "Connection Error"
        }
    }
}

struct SFTPConnection: PDevice, Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authenticationType: AuthenticationType
    var rootPath: String
    var isDefault: Bool
    var lastConnectedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // PDevice conformance
    var deviceType: DeviceType {
        return .sftp
    }

    // Runtime properties (not persisted)
    var status: ConnectionStatus = .disconnected
    var lastError: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case id, name, host, port, username, authenticationType, rootPath, isDefault, lastConnectedAt, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        authenticationType = try container.decode(AuthenticationType.self, forKey: .authenticationType)
        rootPath = try container.decode(String.self, forKey: .rootPath)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Runtime properties are not decoded and use default values
        status = .disconnected
        lastError = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(authenticationType, forKey: .authenticationType)
        try container.encode(rootPath, forKey: .rootPath)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(lastConnectedAt, forKey: .lastConnectedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        // Runtime properties are not encoded
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authenticationType: AuthenticationType = .password,
        rootPath: String = "/",
        isDefault: Bool = false,
        lastConnectedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authenticationType = authenticationType
        self.rootPath = rootPath
        self.isDefault = isDefault
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var connectionString: String {
        return "\(username)@\(host):\(port)"
    }
    
    var isConnected: Bool {
        return status == .connected
    }
    
    mutating func updateStatus(_ newStatus: ConnectionStatus, error: String? = nil) {
        status = newStatus
        lastError = error
        if newStatus == .connected {
            lastConnectedAt = Date()
        }
        updatedAt = Date()
    }
    
    static func == (lhs: SFTPConnection, rhs: SFTPConnection) -> Bool {
        return lhs.id == rhs.id
    }
}