import Foundation

protocol PSFTPKeychainService {
    func savePassword(for connectionId: UUID, password: String) throws
    func getPassword(for connectionId: UUID) -> String?
    func saveSSHKey(for connectionId: UUID, privateKey: String, passphrase: String?) throws
    func getSSHKey(for connectionId: UUID) -> (privateKey: String, passphrase: String?)?
    func deleteCredentials(for connectionId: UUID) throws
}

class SFTPKeychainService: PSFTPKeychainService {
    private let keychain = KeychainService.sftp
    private let logger = Logger.data
    
    private enum CredentialType: String {
        case password = "password"
        case privateKey = "privateKey"
        case passphrase = "passphrase"
    }
    
    // MARK: - Password Management
    
    func savePassword(for connectionId: UUID, password: String) throws {
        let key = credentialKey(for: connectionId, type: .password)
        try keychain.save(key: key, value: password)
        logger.debug("Saved password for connection: \(connectionId)")
    }
    
    func getPassword(for connectionId: UUID) -> String? {
        let key = credentialKey(for: connectionId, type: .password)
        return keychain.get(key: key)
    }
    
    // MARK: - SSH Key Management
    
    func saveSSHKey(for connectionId: UUID, privateKey: String, passphrase: String?) throws {
        let privateKeyKey = credentialKey(for: connectionId, type: .privateKey)
        try keychain.save(key: privateKeyKey, value: privateKey)
        
        if let passphrase = passphrase, !passphrase.isEmpty {
            let passphraseKey = credentialKey(for: connectionId, type: .passphrase)
            try keychain.save(key: passphraseKey, value: passphrase)
        }
        
        logger.debug("Saved SSH key for connection: \(connectionId)")
    }
    
    func getSSHKey(for connectionId: UUID) -> (privateKey: String, passphrase: String?)? {
        let privateKeyKey = credentialKey(for: connectionId, type: .privateKey)
        guard let privateKey = keychain.get(key: privateKeyKey) else {
            return nil
        }
        
        let passphraseKey = credentialKey(for: connectionId, type: .passphrase)
        let passphrase = keychain.get(key: passphraseKey)
        
        return (privateKey: privateKey, passphrase: passphrase)
    }
    
    // MARK: - Cleanup
    
    func deleteCredentials(for connectionId: UUID) throws {
        let passwordKey = credentialKey(for: connectionId, type: .password)
        let privateKeyKey = credentialKey(for: connectionId, type: .privateKey)
        let passphraseKey = credentialKey(for: connectionId, type: .passphrase)
        
        // Delete all credentials - ignoring individual failures since some might not exist
        try? keychain.delete(key: passwordKey)
        try? keychain.delete(key: privateKeyKey)
        try? keychain.delete(key: passphraseKey)
        
        logger.debug("Deleted credentials for connection: \(connectionId)")
    }
    
    // MARK: - Private Helper Methods
    
    private func credentialKey(for connectionId: UUID, type: CredentialType) -> String {
        return "\(connectionId.uuidString)_\(type.rawValue)"
    }
}