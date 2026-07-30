import Foundation

@MainActor
class SFTPDirectoryBrowserViewModel: ObservableObject {
    @Published var directoryItems: [SFTPDirectoryItem] = []
    @Published var currentPath = "/"
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPath: String?
    @Published var favoriteDirectories: [String] = []
    
    private let connection: SFTPConnection
    private let listDirectoryUseCase: ListDirectoryUseCase
    private let manageFavoriteDirectoriesUseCase: ManageFavoriteDirectoriesUseCase
    private let createDirectoryUseCase: CreateSFTPDirectoryUseCase
    @Published private var pathHistory: [String] = ["/"]

    init(
        connection: SFTPConnection,
        factory: PDependencyFactory = DefaultDependencyFactory.shared
    ) {
        self.connection = connection
        self.listDirectoryUseCase = factory.makeListDirectoryUseCase()
        self.manageFavoriteDirectoriesUseCase = factory.makeManageFavoriteDirectoriesUseCase()
        self.createDirectoryUseCase = factory.makeCreateSFTPDirectoryUseCase()

        loadFavoriteDirectories()
    }
    
    var canGoBack: Bool {
        pathHistory.count > 1
    }
    
    var canGoUp: Bool {
        currentPath != "/"
    }
    
    var directories: [SFTPDirectoryItem] {
        directoryItems.filter { $0.isDirectory }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    var files: [SFTPDirectoryItem] {
        directoryItems.filter { !$0.isDirectory }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    func loadDirectory(path: String? = nil) async {
        let targetPath = path ?? currentPath
        
        isLoading = true
        error = nil
        
        do {
            let items = try await listDirectoryUseCase.execute(at: targetPath, connection: connection)
            
            directoryItems = items
            
            if path != nil {
                currentPath = targetPath
                pathHistory.append(targetPath)
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func navigateToDirectory(_ item: SFTPDirectoryItem) async {
        guard item.isDirectory else { return }
        await loadDirectory(path: item.path)
    }
    
    func goBack() async {
        guard pathHistory.count > 1 else { return }
        
        pathHistory.removeLast()
        let previousPath = pathHistory.last ?? "/"
        currentPath = previousPath
        await loadDirectory()
    }
    
    func goUp() async {
        guard currentPath != "/" else { return }
        
        let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        let normalizedPath = parentPath.isEmpty || parentPath == "/" ? "/" : parentPath
        
        await loadDirectory(path: normalizedPath)
    }
    
    func goToRoot() async {
        await loadDirectory(path: "/")
    }
    
    func selectCurrentPath() {
        selectedPath = currentPath
    }
    
    func addToFavorites(_ path: String) {
        print("🔍 SFTP Browser: Adding favorite - path: \(path), connectionId: \(connection.id)")
        do {
            try manageFavoriteDirectoriesUseCase.addFavoriteDirectory(path, for: connection.id)
            print("🔍 SFTP Browser: Successfully added favorite")
            loadFavoriteDirectories()
            print("🔍 SFTP Browser: Favorites reloaded")
        } catch {
            let errorMsg = "Failed to add favorite: \(error.localizedDescription)"
            print("🔍 SFTP Browser: Error adding favorite - \(errorMsg)")
            print("🔍 SFTP Browser: Error type: \(type(of: error))")
            print("🔍 SFTP Browser: Error details: \(error)")
            self.error = errorMsg
        }
    }
    
    func removeFromFavorites(_ path: String) {
        do {
            try manageFavoriteDirectoriesUseCase.removeFavoriteDirectory(path, for: connection.id)
            loadFavoriteDirectories()
        } catch {
            self.error = "Failed to remove favorite: \(error.localizedDescription)"
        }
    }
    
    func navigateToFavorite(_ path: String) async {
        await loadDirectory(path: path)
    }
    
    func createDirectory(name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Directory name cannot be empty"
            return
        }
        
        let newDirPath = currentPath.hasSuffix("/") ? "\(currentPath)\(name)" : "\(currentPath)/\(name)"
        
        do {
            try await createDirectoryUseCase.execute(at: newDirPath, connection: connection)
            await loadDirectory()
        } catch {
            self.error = "Failed to create directory: \(error.localizedDescription)"
        }
    }
    
    private func loadFavoriteDirectories() {
        favoriteDirectories = manageFavoriteDirectoriesUseCase.getFavoriteDirectories(for: connection.id)
    }
    
    var currentPathComponents: [String] {
        guard currentPath != "/" else { return ["Root"] }
        
        let components = currentPath.split(separator: "/").map(String.init)
        return ["Root"] + components
    }
    
    func navigateToPathComponent(at index: Int) async {
        let components = currentPath.split(separator: "/").map(String.init)
        
        if index == 0 {
            await goToRoot()
            return
        }
        
        let targetComponents = Array(components.prefix(index))
        let targetPath = "/" + targetComponents.joined(separator: "/")
        
        await loadDirectory(path: targetPath)
    }
}