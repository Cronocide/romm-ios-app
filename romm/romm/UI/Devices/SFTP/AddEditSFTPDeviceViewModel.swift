import Foundation

@MainActor
@Observable
class AddEditSFTPDeviceViewModel {
    var name = ""
    var host = ""
    var port = "22"
    var username = ""
    var authenticationType: AuthenticationType = .password
    var password = ""
    var privateKey = ""
    var passphrase = ""
    var rootPath = "/"
    var isDefault = false
    
    var isLoading = false
    var error: String?
    var isTestingConnection = false
    var testResult: ConnectionStatus?
    
    private let getCredentialsUseCase: GetCredentialsUseCase
    private let testConnectionUseCase: TestConnectionUseCase
    private var editingConnection: SFTPConnection?

    var isEditing: Bool {
        editingConnection != nil
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(port) != nil &&
        Int(port)! > 0 &&
        Int(port)! <= 65535 &&
        isAuthenticationValid
    }

    private var isAuthenticationValid: Bool {
        switch authenticationType {
        case .password:
            return !password.isEmpty
        case .sshKey:
            return !privateKey.isEmpty
        case .passwordWithKey:
            return !password.isEmpty && !privateKey.isEmpty
        }
    }

    init(
        connection: SFTPConnection? = nil,
        factory: PDependencyFactory = DefaultDependencyFactory.shared
    ) {
        self.getCredentialsUseCase = factory.makeGetCredentialsUseCase()
        self.testConnectionUseCase = factory.makeTestConnectionUseCase()
        self.editingConnection = connection

        if let connection = connection {
            loadConnection(connection)
        }
    }
    
    private func loadConnection(_ connection: SFTPConnection) {
        name = connection.name
        host = connection.host
        port = String(connection.port)
        username = connection.username
        authenticationType = connection.authenticationType
        rootPath = connection.rootPath
        isDefault = connection.isDefault
        
        // Load credentials from keychain
        if let credentials = getCredentialsUseCase.execute(for: connection.id) {
            password = credentials.password ?? ""
            privateKey = credentials.privateKey ?? ""
            passphrase = credentials.passphrase ?? ""
        }
    }
    
    func testConnection() async {
        guard isValid else {
            error = "Please fill in all required fields correctly"
            return
        }
        
        isTestingConnection = true
        testResult = nil
        error = nil
        
        let testConnection = createConnection()
        let testCredentials = createCredentials()
        
        do {
            let isConnected = try await testConnectionUseCase.executeWithCredentialsThrows(testConnection, credentials: testCredentials)
            testResult = isConnected ? .connected : .error
            
            if !isConnected {
                error = "Connection test failed. Please check your credentials and network connection."
            }
        } catch {
            testResult = .error
            self.error = "Connection test failed: \(error.localizedDescription)"
        }
        
        isTestingConnection = false
    }
    
    func saveConnection() -> (connection: SFTPConnection, credentials: SFTPCredentials)? {
        guard isValid else {
            error = "Please fill in all required fields correctly"
            return nil
        }
        
        guard let portInt = Int(port), portInt > 0, portInt <= 65535 else {
            error = "Port must be a number between 1 and 65535"
            return nil
        }
        
        let connection = createConnection()
        let credentials = createCredentials()
        error = nil
        
        return (connection: connection, credentials: credentials)
    }
    
    private func createCredentials() -> SFTPCredentials {
        return SFTPCredentials(
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            authenticationType: authenticationType,
            password: password.isEmpty ? nil : password,
            privateKey: privateKey.isEmpty ? nil : privateKey,
            passphrase: passphrase.isEmpty ? nil : passphrase
        )
    }
    
    private func createConnection() -> SFTPConnection {
        let connectionId = editingConnection?.id ?? UUID()
        let createdAt = editingConnection?.createdAt ?? Date()
        
        return SFTPConnection(
            id: connectionId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            authenticationType: authenticationType,
            rootPath: rootPath.isEmpty ? "/" : rootPath,
            isDefault: isDefault,
            lastConnectedAt: editingConnection?.lastConnectedAt,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func clearForm() {
        name = ""
        host = ""
        port = "22"
        username = ""
        authenticationType = .password
        password = ""
        privateKey = ""
        passphrase = ""
        rootPath = "/"
        isDefault = false
        error = nil
        testResult = nil
        isTestingConnection = false
    }
}