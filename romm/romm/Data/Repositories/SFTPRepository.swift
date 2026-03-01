import Foundation
import Combine

class SFTPRepository: PSFTPRepository {
    private let logger = Logger.data
    private let userDefaults = UserDefaults.standard
    private let keychainService: PSFTPKeychainService
    
    private let connectionsKey = "sftp_connections"
    private let favoritesKeyPrefix = "sftp_favorites_"
    
    private var connections: [SFTPConnection] = []
    
    init(keychainService: PSFTPKeychainService = SFTPKeychainService()) {
        self.keychainService = keychainService
        loadConnections()
    }
    
    func getAllConnections() -> [SFTPConnection] {
        return connections
    }
    
    func getConnection(by id: UUID) -> SFTPConnection? {
        return connections.first { $0.id == id }
    }
    
    func saveConnection(_ connection: SFTPConnection, credentials: SFTPCredentials) throws {
        logger.info("Saving SFTP connection: \(connection.name)")
        
        // Save credentials to keychain
        switch connection.authenticationType {
        case .password:
            if let password = credentials.password, !password.isEmpty {
                try keychainService.savePassword(for: connection.id, password: password)
            }
            
        case .sshKey:
            if let privateKey = credentials.privateKey, !privateKey.isEmpty {
                try keychainService.saveSSHKey(
                    for: connection.id,
                    privateKey: privateKey,
                    passphrase: credentials.passphrase
                )
            }
            
        case .passwordWithKey:
            if let password = credentials.password, !password.isEmpty,
               let privateKey = credentials.privateKey, !privateKey.isEmpty {
                try keychainService.savePassword(for: connection.id, password: password)
                try keychainService.saveSSHKey(
                    for: connection.id,
                    privateKey: privateKey,
                    passphrase: credentials.passphrase
                )
            }
        }
        
        // Save connection info (without credentials)
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        
        try persistConnections()
    }
    
    func deleteConnection(_ connection: SFTPConnection) throws {
        logger.info("Deleting SFTP connection: \(connection.name)")
        
        // Remove from connections list
        connections.removeAll { $0.id == connection.id }
        
        // Remove favorites
        let favoritesKey = favoritesKeyPrefix + connection.id.uuidString
        userDefaults.removeObject(forKey: favoritesKey)
        
        // Remove credentials from keychain
        try keychainService.deleteCredentials(for: connection.id)
        
        try persistConnections()
    }
    
    func setDefaultConnection(_ connection: SFTPConnection) throws {
        logger.info("Setting default SFTP connection: \(connection.name)")
        
        connections = connections.map { conn in
            var updatedConn = conn
            updatedConn.isDefault = (conn.id == connection.id)
            return updatedConn
        }
        
        try persistConnections()
    }
    
    func getDefaultConnection() -> SFTPConnection? {
        return connections.first { $0.isDefault }
    }
    
    func getCredentials(for connectionId: UUID) -> SFTPCredentials? {
        guard let connection = getConnection(by: connectionId) else { return nil }
        
        var credentials = SFTPCredentials(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            authenticationType: connection.authenticationType
        )
        
        switch connection.authenticationType {
        case .password:
            credentials.password = keychainService.getPassword(for: connectionId)
            
        case .sshKey:
            if let sshKey = keychainService.getSSHKey(for: connectionId) {
                credentials.privateKey = sshKey.privateKey
                credentials.passphrase = sshKey.passphrase
            }
            
        case .passwordWithKey:
            credentials.password = keychainService.getPassword(for: connectionId)
            if let sshKey = keychainService.getSSHKey(for: connectionId) {
                credentials.privateKey = sshKey.privateKey
                credentials.passphrase = sshKey.passphrase
            }
        }
        
        return credentials
    }
    
    func getFavoriteDirectories(for connectionId: UUID) -> [String] {
        let favoritesKey = favoritesKeyPrefix + connectionId.uuidString
        return userDefaults.array(forKey: favoritesKey) as? [String] ?? []
    }
    
    func addFavoriteDirectory(_ path: String, for connectionId: UUID) throws {
        logger.info("Adding favorite directory: \(path) for connection: \(connectionId)")
        print("🔍 SFTP Repository: Adding favorite - path: \(path), connectionId: \(connectionId)")
        
        let favoritesKey = favoritesKeyPrefix + connectionId.uuidString
        print("🔍 SFTP Repository: Favorites key: \(favoritesKey)")
        
        var favorites = getFavoriteDirectories(for: connectionId)
        print("🔍 SFTP Repository: Current favorites: \(favorites)")
        
        if !favorites.contains(path) {
            favorites.append(path)
            print("🔍 SFTP Repository: New favorites list: \(favorites)")
            userDefaults.set(favorites, forKey: favoritesKey)
            print("🔍 SFTP Repository: UserDefaults set successful")
        } else {
            print("🔍 SFTP Repository: Path already in favorites, skipping")
        }
    }
    
    func removeFavoriteDirectory(_ path: String, for connectionId: UUID) throws {
        logger.info("Removing favorite directory: \(path) for connection: \(connectionId)")
        
        let favoritesKey = favoritesKeyPrefix + connectionId.uuidString
        var favorites = getFavoriteDirectories(for: connectionId)
        
        favorites.removeAll { $0 == path }
        userDefaults.set(favorites, forKey: favoritesKey)
    }
    
    private func loadConnections() {
        logger.info("Loading SFTP connections from UserDefaults")
        
        guard let data = userDefaults.data(forKey: connectionsKey) else {
            logger.info("No SFTP connections found in UserDefaults")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            connections = try decoder.decode([SFTPConnection].self, from: data)
            logger.info("Loaded \(connections.count) SFTP connections")
        } catch {
            logger.error("Failed to decode SFTP connections: \(error)")
            connections = []
        }
    }
    
    private func persistConnections() throws {
        logger.info("Persisting \(connections.count) SFTP connections to UserDefaults")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(connections)
            userDefaults.set(data, forKey: connectionsKey)
        } catch {
            logger.error("Failed to encode SFTP connections: \(error)")
            throw error
        }
    }
}
