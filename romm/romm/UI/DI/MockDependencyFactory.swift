//
//  MockDependencyFactory.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//


// MARK: - Mock Factory for Testing

class MockDependencyFactory: DependencyFactoryProtocol {
    var transferHistoryRepository: TransferHistoryRepositoryProtocol
    var localROMRepository: LocalROMRepositoryProtocol

    // Mock repositories can be injected for testing
    var authRepository: AuthRepositoryProtocol
    var romsRepository: RomsRepositoryProtocol
    var platformsRepository: PlatformsRepositoryProtocol
    var collectionsRepository: CollectionsRepositoryProtocol
    var setupRepository: SetupRepositoryProtocol
    var sftpRepository: SFTPRepositoryProtocol
    var fileSystemRepository: FileSystemRepositoryProtocol
    var statsRepository: StatsRepositoryProtocol
    var heartbeatRepository: HeartbeatRepositoryProtocol

    // Mock services
    var sftpKeychainService: SFTPKeychainServiceProtocol
    var sftpService: SFTPServiceProtocol
    var sftpConnectionManager: SFTPConnectionManager
    var apiClient: RommAPIClientProtocol
    var fileValidationService: FileValidationServiceProtocol
    
    init(
        authRepository: AuthRepositoryProtocol? = nil,
        romsRepository: RomsRepositoryProtocol? = nil,
        platformsRepository: PlatformsRepositoryProtocol? = nil,
        collectionsRepository: CollectionsRepositoryProtocol? = nil,
        setupRepository: SetupRepositoryProtocol? = nil,
        sftpRepository: SFTPRepositoryProtocol? = nil,
        fileSystemRepository: FileSystemRepositoryProtocol? = nil,
        statsRepository: StatsRepositoryProtocol? = nil,
        sftpKeychainService: SFTPKeychainServiceProtocol? = nil,
        sftpService: SFTPServiceProtocol? = nil,
        sftpConnectionManager: SFTPConnectionManager? = nil,
        apiClient: RommAPIClientProtocol? = nil,
        fileValidationService: FileValidationServiceProtocol? = nil
    ) {
        // Use provided mocks or default to real implementations
        self.authRepository = authRepository ?? AuthRepository()
        self.romsRepository = romsRepository ?? RomsRepository()
        self.platformsRepository = platformsRepository ?? PlatformsRepository()
        self.collectionsRepository = collectionsRepository ?? CollectionsRepository()
        self.setupRepository = setupRepository ?? SetupRepository()
        self.fileSystemRepository = fileSystemRepository ?? FileSystemRepository()
        self.statsRepository = statsRepository ?? StatsRepository()
        self.heartbeatRepository = HeartbeatRepository()

        let keychainService = sftpKeychainService ?? SFTPKeychainService()
        self.sftpKeychainService = keychainService
        self.sftpRepository = sftpRepository ?? SFTPRepository(keychainService: keychainService)
        self.fileValidationService = fileValidationService ?? FileValidationService()
        self.sftpService = sftpService ?? SFTPService(repository: self.sftpRepository)
        
        if let providedManager = sftpConnectionManager {
            self.sftpConnectionManager = providedManager
        } else {
            let manager = SFTPConnectionManager.shared
            manager.configure(with: self.sftpService)
            self.sftpConnectionManager = manager
        }
        
        self.apiClient = apiClient ?? RommAPIClient.shared
        transferHistoryRepository = TransferHistoryRepository()
        localROMRepository = LocalROMRepository()
    }
    
    func makeLogoutUseCase() -> LogoutUseCase {
        LogoutUseCase(authRepository: authRepository)
    }
    
    func makeGetCurrentUserUseCase() -> GetCurrentUserUseCase {
        GetCurrentUserUseCase(authRepository: authRepository)
    }
    
    func makeGetRomsUseCase() -> GetRomsUseCase {
        GetRomsUseCase(romsRepository: romsRepository)
    }
    
    func makeGetRomsWithFiltersUseCase() -> GetRomsWithFiltersUseCase {
        GetRomsWithFiltersUseCase(romsRepository: romsRepository)
    }
    
    func makeGetRomDetailsUseCase() -> GetRomDetailsUseCase {
        GetRomDetailsUseCase(romsRepository: romsRepository)
    }
    
    func makeToggleRomFavoriteUseCase() -> ToggleRomFavoriteUseCase {
        ToggleRomFavoriteUseCase(romsRepository: romsRepository)
    }
    
    func makeCheckRomFavoriteStatusUseCase() -> CheckRomFavoriteStatusUseCase {
        CheckRomFavoriteStatusUseCase(romsRepository: romsRepository)
    }
    
    func makeSearchRomsUseCase() -> SearchRomsUseCase {
        SearchRomsUseCase(romsRepository: romsRepository)
    }
    
    func makeLoadManualUseCase() -> LoadManualUseCase {
        LoadManualUseCase()
    }
    
    func makeGetPlatformsUseCase() -> GetPlatformsUseCase {
        GetPlatformsUseCase(platformsRepository: platformsRepository)
    }
    
    func makeAddPlatformUseCase() -> AddPlatformUseCase {
        AddPlatformUseCase(platformsRepository: platformsRepository)
    }

    func makeGetStatsUseCase() -> GetStatsUseCase {
        GetStatsUseCase(statsRepository: statsRepository)
    }

    func makeGetHeartbeatUseCase() -> GetHeartbeatUseCase {
        GetHeartbeatUseCase(heartbeatRepository: heartbeatRepository)
    }

    func makeCheckServerVersionUseCase() -> CheckServerVersionUseCase {
        CheckServerVersionUseCase(heartbeatRepository: heartbeatRepository)
    }

    func makeClearServerVersionUseCase() -> ClearServerVersionUseCase {
        ClearServerVersionUseCase(heartbeatRepository: heartbeatRepository)
    }

    func makeSaveServerVersionUseCase() -> SaveServerVersionUseCase {
        SaveServerVersionUseCase(heartbeatRepository: heartbeatRepository)
    }

    func makeGetCollectionsUseCase() -> GetCollectionsUseCase {
        GetCollectionsUseCase(collectionsRepository: collectionsRepository)
    }
    
    func makeGetVirtualCollectionsUseCase() -> GetVirtualCollectionsUseCase {
        GetVirtualCollectionsUseCase(collectionsRepository: collectionsRepository)
    }
    
    func makeCreateCollectionUseCase() -> CreateCollectionUseCase {
        CreateCollectionUseCase(collectionsRepository: collectionsRepository)
    }
    
    func makeUpdateCollectionUseCase() -> UpdateCollectionUseCase {
        UpdateCollectionUseCase(collectionsRepository: collectionsRepository)
    }
    
    func makeDeleteCollectionUseCase() -> DeleteCollectionUseCase {
        DeleteCollectionUseCase(collectionsRepository: collectionsRepository)
    }
    
    func makeSaveSetupConfigurationUseCase() -> SaveSetupConfigurationUseCaseProtocol {
        SaveSetupConfigurationUseCase(
            setupRepository: setupRepository
        )
    }
    
    func makeGetSetupConfigurationUseCase() -> GetSetupConfigurationUseCaseProtocol {
        GetSetupConfigurationUseCase(setupRepository: setupRepository)
    }
    
    func makeCheckSetupStatusUseCase() -> CheckSetupStatusUseCaseProtocol {
        CheckSetupStatusUseCase(setupRepository: setupRepository)
    }
    
    func makeClearSetupConfigurationUseCase() -> ClearSetupConfigurationUseCaseProtocol {
        ClearSetupConfigurationUseCase(
            setupRepository: setupRepository,
            configurationService: DefaultConfigurationService.shared
        )
    }
    
    // MARK: - SFTP Use Cases
    
    func makeGetAllConnectionsUseCase() -> GetAllConnectionsUseCase {
        GetAllConnectionsUseCase(repository: sftpRepository)
    }
    
    func makeListDirectoryUseCase() -> ListDirectoryUseCase {
        ListDirectoryUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeUploadFileUseCase() -> UploadFileUseCase {
        UploadFileUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeTestConnectionUseCase() -> TestConnectionUseCase {
        TestConnectionUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeSaveConnectionUseCase() -> SaveConnectionUseCase {
        SaveConnectionUseCase(repository: sftpRepository)
    }
    
    func makeDeleteConnectionUseCase() -> DeleteConnectionUseCase {
        DeleteConnectionUseCase(repository: sftpRepository)
    }
    
    func makeManageDefaultConnectionUseCase() -> ManageDefaultConnectionUseCase {
        ManageDefaultConnectionUseCase(repository: sftpRepository)
    }
    
    func makeManageFavoriteDirectoriesUseCase() -> ManageFavoriteDirectoriesUseCase {
        ManageFavoriteDirectoriesUseCase(repository: sftpRepository)
    }
    
    func makeCreateSFTPDirectoryUseCase() -> CreateSFTPDirectoryUseCase {
        CreateSFTPDirectoryUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeCheckConnectionStatusUseCase() -> CheckConnectionStatusUseCase {
        CheckConnectionStatusUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeClearConnectionCacheUseCase() -> ClearConnectionCacheUseCase {
        ClearConnectionCacheUseCase(connectionManager: sftpConnectionManager)
    }
    
    func makeGetCredentialsUseCase() -> GetCredentialsUseCase {
        GetCredentialsUseCase(repository: sftpRepository)
    }
    
    // MARK: - UI Use Cases
    
    func makeGetViewModeUseCase() -> GetViewModeUseCaseProtocol {
        GetViewModeUseCase()
    }
    
    func makeSaveViewModeUseCase() -> SaveViewModeUseCaseProtocol {
        SaveViewModeUseCase()
    }
    
    // MARK: - SFTP ViewModels
    
    @MainActor func makeSFTPDevicesViewModel() -> SFTPDevicesViewModel {
        SFTPDevicesViewModel()
    }
    
    @MainActor func makeSFTPDirectoryBrowserViewModel(connection: SFTPConnection) -> SFTPDirectoryBrowserViewModel {
        SFTPDirectoryBrowserViewModel(
            connection: connection,
            factory: self
        )
    }

    @MainActor func makeSFTPUploadViewModel(rom: Rom) -> SFTPUploadViewModel {
        SFTPUploadViewModel(
            rom: rom,
            factory: self
        )
    }

    @MainActor func makeAddEditSFTPDeviceViewModel(connection: SFTPConnection?) -> AddEditSFTPDeviceViewModel {
        AddEditSFTPDeviceViewModel(
            connection: connection,
            factory: self
        )   
    }
    
    func makeSaveTransferHistoryUseCase() -> SaveTransferHistoryUseCase {
        .init(repository: transferHistoryRepository)
    }
    
    func makeGetTransferHistoryUseCase() -> GetTransferHistoryUseCase {
        .init(repository: transferHistoryRepository)
    }
    
    func makeGetTransferHistoryGroupedByPlatformUseCase() -> GetTransferHistoryGroupedByPlatformUseCase {
        .init(repository: transferHistoryRepository)
    }
    
    func makeClearTransferHistoryUseCase() -> ClearTransferHistoryUseCase {
        .init(repository: transferHistoryRepository)
    }
    
    func makeCheckEmulatorSupportUseCase() -> CheckEmulatorSupportUseCaseProtocol {
        CheckEmulatorSupportUseCase()
    }

    func makeLaunchEmulatorUseCase() -> LaunchEmulatorUseCaseProtocol {
        LaunchEmulatorUseCase(
            tokenProvider: TokenProvider(),
            checkEmulatorSupport: makeCheckEmulatorSupportUseCase()
        )
    }
}
