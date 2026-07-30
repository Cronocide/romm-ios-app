import Foundation

// This is the only view model that is not @MainActor as a whole. Rather than
// isolating the class -- which would cascade into `onSave: viewModel.saveConnection`
// (a bare closure reference in SFTPDevicesView) and into deinit ->
// cancelAllConnectionTests() -- only the async entry points that could run off
// the main thread are isolated. loadConnections() stays non-isolated: a
// non-isolated sync function runs on its caller's thread, so main-isolated
// callers make its @Published mutations main-safe.
class SFTPDevicesViewModel: ObservableObject {
    @Published var connections: [SFTPConnection] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showingAddDevice = false
    @Published var editingConnection: SFTPConnection?

    // Track running connection tests to allow cancellation.
    // Not @Published: bookkeeping that no view reads, and deinit touches it.
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    // Prevent repeated loading on every view appear
    private var hasLoadedOnce = false
    
    private let getAllConnectionsUseCase: GetAllConnectionsUseCase
    private let saveConnectionUseCase: SaveConnectionUseCase
    private let deleteConnectionUseCase: DeleteConnectionUseCase
    private let manageDefaultConnectionUseCase: ManageDefaultConnectionUseCase
    private let testConnectionUseCase: TestConnectionUseCase
    private let checkConnectionStatusUseCase: CheckConnectionStatusUseCase
    private let clearConnectionCacheUseCase: ClearConnectionCacheUseCase
    
    init(_ factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.getAllConnectionsUseCase = factory.makeGetAllConnectionsUseCase()
        self.saveConnectionUseCase = factory.makeSaveConnectionUseCase()
        self.deleteConnectionUseCase = factory.makeDeleteConnectionUseCase()
        self.manageDefaultConnectionUseCase = factory.makeManageDefaultConnectionUseCase()
        self.testConnectionUseCase = factory.makeTestConnectionUseCase()
        self.checkConnectionStatusUseCase = factory.makeCheckConnectionStatusUseCase()
        self.clearConnectionCacheUseCase = factory.makeClearConnectionCacheUseCase()
    }
    
    func loadConnections() {
        connections = getAllConnectionsUseCase.execute()
    }

    @MainActor
    func loadConnectionsAsync() async {
        // Only load once per ViewModel lifecycle to prevent repeated tests on every screen open
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true

        loadConnections()

        // Load cached statuses first (instant, no network calls)
        await loadStatusesFromCache()

        // Only refresh if we have no cached data at all
        let needsRefresh = connections.allSatisfy { $0.status == .disconnected }

        if needsRefresh {
            await refreshConnectionStatuses()
        }
    }
    
    @MainActor
    func forceRefreshConnections() async {
        loadConnections()
        await refreshConnectionStatuses()
    }
    
    func addDevice() {
        editingConnection = nil
        showingAddDevice = true
    }
    
    func editDevice(_ connection: SFTPConnection) {
        editingConnection = connection
        showingAddDevice = true
    }
    
    func saveConnection(_ connection: SFTPConnection, credentials: SFTPCredentials) {
        do {
            try saveConnectionUseCase.execute(connection, credentials: credentials)
            showingAddDevice = false
            editingConnection = nil
            error = nil
            loadConnections() // Reload to get updated data
        } catch {
            self.error = "Failed to save connection: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func deleteConnection(_ connection: SFTPConnection) async {
        do {
            try deleteConnectionUseCase.execute(connection)
            await clearConnectionCacheUseCase.execute(for: connection)
            error = nil
            loadConnections() // Reload to get updated data
        } catch {
            self.error = "Failed to delete connection: \(error.localizedDescription)"
        }
    }
    
    func setDefaultConnection(_ connection: SFTPConnection) {
        do {
            try manageDefaultConnectionUseCase.setDefaultConnection(connection)
            error = nil
            loadConnections() // Reload to get updated data
        } catch {
            self.error = "Failed to set default connection: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func testConnection(_ connection: SFTPConnection) {
        // Cancel any existing test for this connection
        runningTasks[connection.id]?.cancel()
        
        // Immediately update UI to show testing state (non-blocking)
        connections = connections.map { conn in
            var updatedConnection = conn
            if updatedConnection.id == connection.id {
                updatedConnection.status = .connecting
            }
            return updatedConnection
        }
        
        // Perform actual test in background with proper cancellation support
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                let status = await self.checkConnectionStatusUseCase.execute(for: connection, forceRefresh: true)
                
                // Only update UI if task wasn't cancelled and self still exists
                guard !Task.isCancelled else { return }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.connections = self.connections.map { conn in
                        var updatedConnection = conn
                        if updatedConnection.id == connection.id {
                            updatedConnection.status = status
                        }
                        return updatedConnection
                    }
                    // Remove completed task
                    self.runningTasks.removeValue(forKey: connection.id)
                }
            } catch {
                // Handle cancellation gracefully
                await MainActor.run { [weak self] in
                    guard let self = self, !Task.isCancelled else { return }
                    self.connections = self.connections.map { conn in
                        var updatedConnection = conn
                        if updatedConnection.id == connection.id {
                            updatedConnection.status = .error
                        }
                        return updatedConnection
                    }
                    self.runningTasks.removeValue(forKey: connection.id)
                }
            }
        }
        
        // Store task for potential cancellation
        runningTasks[connection.id] = task
    }
    
    @MainActor
    func refreshConnectionStatuses() async {
        // Set all connections to connecting state immediately for UI feedback
        await MainActor.run {
            self.connections = self.connections.map { conn in
                var updatedConnection = conn
                updatedConnection.status = .connecting
                return updatedConnection
            }
        }

        // Check all connections in parallel (fast!)
        // This already updates the cache AND the local connections array
        await checkConnectionStatusUseCase.executeForAllConnections(for: connections, forceRefresh: true)

        // Load updated statuses from cache (instant - no redundant network calls)
        await loadStatusesFromCache()
    }

    // Load connection statuses from cache only (no network calls)
    @MainActor
    private func loadStatusesFromCache() async {
        for i in 0..<connections.count {
            let status = await checkConnectionStatusUseCase.execute(for: connections[i], forceRefresh: false)
            await MainActor.run {
                self.connections[i].status = status
            }
        }
    }

    // Cancel all running connection tests (call when view disappears)
    func cancelAllConnectionTests() {
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
    }
    
    deinit {
        cancelAllConnectionTests()
    }
}
