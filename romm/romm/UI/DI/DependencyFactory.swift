//
//  DependencyFactory.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

protocol DependencyFactoryProtocol {
    // Repositories
    var authRepository: AuthRepositoryProtocol { get }
    var romsRepository: RomsRepositoryProtocol { get }
    var platformsRepository: PlatformsRepositoryProtocol { get }
    var collectionsRepository: CollectionsRepositoryProtocol { get }
    var setupRepository: SetupRepositoryProtocol { get }
    var sftpRepository: SFTPRepositoryProtocol { get }
    var fileSystemRepository: FileSystemRepositoryProtocol { get }
    var transferHistoryRepository: TransferHistoryRepositoryProtocol { get }
    var localROMRepository: LocalROMRepositoryProtocol { get }
    var statsRepository: StatsRepositoryProtocol { get }
    var heartbeatRepository: HeartbeatRepositoryProtocol { get }

    // Services
    var sftpKeychainService: SFTPKeychainServiceProtocol { get }
    var sftpService: SFTPServiceProtocol { get }
    var sftpConnectionManager: SFTPConnectionManager { get }
    var apiClient: RommAPIClientProtocol { get }
    var fileValidationService: FileValidationServiceProtocol { get }
    
    // Use Cases
    func makeLogoutUseCase() -> LogoutUseCase
    func makeGetCurrentUserUseCase() -> GetCurrentUserUseCase
    func makeGetRomsUseCase() -> GetRomsUseCase
    func makeGetRomsWithFiltersUseCase() -> GetRomsWithFiltersUseCase
    func makeGetRomDetailsUseCase() -> GetRomDetailsUseCase
    func makeToggleRomFavoriteUseCase() -> ToggleRomFavoriteUseCase
    func makeCheckRomFavoriteStatusUseCase() -> CheckRomFavoriteStatusUseCase
    func makeSearchRomsUseCase() -> SearchRomsUseCase
    func makeLoadManualUseCase() -> LoadManualUseCase
    func makeGetPlatformsUseCase() -> GetPlatformsUseCase
    func makeAddPlatformUseCase() -> AddPlatformUseCase
    func makeGetStatsUseCase() -> GetStatsUseCase
    func makeGetHeartbeatUseCase() -> GetHeartbeatUseCase
    func makeCheckServerVersionUseCase() -> CheckServerVersionUseCase
    func makeClearServerVersionUseCase() -> ClearServerVersionUseCase
    func makeSaveServerVersionUseCase() -> SaveServerVersionUseCase
    func makeGetCollectionsUseCase() -> GetCollectionsUseCase
    func makeGetVirtualCollectionsUseCase() -> GetVirtualCollectionsUseCase
    func makeCreateCollectionUseCase() -> CreateCollectionUseCase
    func makeUpdateCollectionUseCase() -> UpdateCollectionUseCase
    func makeDeleteCollectionUseCase() -> DeleteCollectionUseCase
    
    // Setup Use Cases
    func makeSaveSetupConfigurationUseCase() -> SaveSetupConfigurationUseCaseProtocol
    func makeGetSetupConfigurationUseCase() -> GetSetupConfigurationUseCaseProtocol
    func makeCheckSetupStatusUseCase() -> CheckSetupStatusUseCaseProtocol
    func makeClearSetupConfigurationUseCase() -> ClearSetupConfigurationUseCaseProtocol
    
    // SFTP Use Cases
    func makeGetAllConnectionsUseCase() -> GetAllConnectionsUseCase
    func makeListDirectoryUseCase() -> ListDirectoryUseCase
    func makeUploadFileUseCase() -> UploadFileUseCase
    func makeTestConnectionUseCase() -> TestConnectionUseCase
    func makeSaveConnectionUseCase() -> SaveConnectionUseCase
    func makeDeleteConnectionUseCase() -> DeleteConnectionUseCase
    func makeManageDefaultConnectionUseCase() -> ManageDefaultConnectionUseCase
    func makeManageFavoriteDirectoriesUseCase() -> ManageFavoriteDirectoriesUseCase
    func makeCreateSFTPDirectoryUseCase() -> CreateSFTPDirectoryUseCase
    func makeCheckConnectionStatusUseCase() -> CheckConnectionStatusUseCase
    func makeClearConnectionCacheUseCase() -> ClearConnectionCacheUseCase
    func makeGetCredentialsUseCase() -> GetCredentialsUseCase

    // Transfer History Use Cases
    func makeSaveTransferHistoryUseCase() -> SaveTransferHistoryUseCase
    func makeGetTransferHistoryUseCase() -> GetTransferHistoryUseCase
    func makeGetTransferHistoryGroupedByPlatformUseCase() -> GetTransferHistoryGroupedByPlatformUseCase
    func makeClearTransferHistoryUseCase() -> ClearTransferHistoryUseCase
    
    // UI Use Cases
    func makeGetViewModeUseCase() -> GetViewModeUseCaseProtocol
    func makeSaveViewModeUseCase() -> SaveViewModeUseCaseProtocol

    // Emulator Use Cases
    func makeCheckEmulatorSupportUseCase() -> CheckEmulatorSupportUseCaseProtocol
    func makeLaunchEmulatorUseCase() -> LaunchEmulatorUseCaseProtocol

    // SFTP ViewModels
    @MainActor func makeSFTPDevicesViewModel() -> SFTPDevicesViewModel
    @MainActor func makeSFTPDirectoryBrowserViewModel(connection: SFTPConnection) -> SFTPDirectoryBrowserViewModel
    @MainActor func makeSFTPUploadViewModel(rom: Rom) -> SFTPUploadViewModel
    @MainActor func makeAddEditSFTPDeviceViewModel(connection: SFTPConnection?) -> AddEditSFTPDeviceViewModel
}

class DefaultDependencyFactory: DependencyFactoryProtocol {
    func makeSFTPDevicesViewModel() -> SFTPDevicesViewModel {
        SFTPDevicesViewModel()
    }
    
    static let shared = DefaultDependencyFactory()
    
    // MARK: - Repositories (Singletons)
    
    lazy var authRepository: AuthRepositoryProtocol = AuthRepository()
    lazy var romsRepository: RomsRepositoryProtocol = RomsRepository()
    lazy var platformsRepository: PlatformsRepositoryProtocol = PlatformsRepository()
    lazy var collectionsRepository: CollectionsRepositoryProtocol = CollectionsRepository()
    lazy var setupRepository: SetupRepositoryProtocol = SetupRepository()
    lazy var fileSystemRepository: FileSystemRepositoryProtocol = FileSystemRepository()
    lazy var transferHistoryRepository: TransferHistoryRepositoryProtocol = TransferHistoryRepository()
    lazy var localROMRepository: LocalROMRepositoryProtocol = LocalROMRepository()
    lazy var statsRepository: StatsRepositoryProtocol = StatsRepository()
    lazy var heartbeatRepository: HeartbeatRepositoryProtocol = HeartbeatRepository()
    
    // MARK: - Services (Singletons)
    
    lazy var fileValidationService: FileValidationServiceProtocol = FileValidationService()
    
    // MARK: - SFTP Services (Singletons)
    
    lazy var sftpKeychainService: SFTPKeychainServiceProtocol = SFTPKeychainService()
    lazy var sftpRepository: SFTPRepositoryProtocol = SFTPRepository(keychainService: sftpKeychainService)
    lazy var sftpService: SFTPServiceProtocol = SFTPService(repository: sftpRepository)
    lazy var sftpConnectionManager: SFTPConnectionManager = {
        let manager = SFTPConnectionManager.shared
        manager.configure(with: sftpService)
        return manager
    }()
    lazy var apiClient: RommAPIClientProtocol = RommAPIClient.shared
    
    private init() {}
    
    // MARK: - Auth Use Cases
    
    func makeLogoutUseCase() -> LogoutUseCase {
        LogoutUseCase(authRepository: authRepository)
    }
    
    func makeGetCurrentUserUseCase() -> GetCurrentUserUseCase {
        GetCurrentUserUseCase(authRepository: authRepository)
    }
    
    // MARK: - ROM Use Cases
    
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
    
    // MARK: - Platform Use Cases
    
    func makeGetPlatformsUseCase() -> GetPlatformsUseCase {
        GetPlatformsUseCase(platformsRepository: platformsRepository)
    }
    
    func makeAddPlatformUseCase() -> AddPlatformUseCase {
        AddPlatformUseCase(platformsRepository: platformsRepository)
    }

    // MARK: - Stats Use Cases

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

    // MARK: - Collection Use Cases
    
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
    
    // MARK: - Setup Use Cases
    
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

    // MARK: - Transfer History Use Cases

    func makeSaveTransferHistoryUseCase() -> SaveTransferHistoryUseCase {
        SaveTransferHistoryUseCase(repository: transferHistoryRepository)
    }

    func makeGetTransferHistoryUseCase() -> GetTransferHistoryUseCase {
        GetTransferHistoryUseCase(repository: transferHistoryRepository)
    }

    func makeGetTransferHistoryGroupedByPlatformUseCase() -> GetTransferHistoryGroupedByPlatformUseCase {
        GetTransferHistoryGroupedByPlatformUseCase(repository: transferHistoryRepository)
    }

    func makeClearTransferHistoryUseCase() -> ClearTransferHistoryUseCase {
        ClearTransferHistoryUseCase(repository: transferHistoryRepository)
    }

    // MARK: - UI Use Cases

    func makeGetViewModeUseCase() -> GetViewModeUseCaseProtocol {
        GetViewModeUseCase()
    }

    func makeSaveViewModeUseCase() -> SaveViewModeUseCaseProtocol {
        SaveViewModeUseCase()
    }

    // MARK: - Emulator Use Cases

    func makeCheckEmulatorSupportUseCase() -> CheckEmulatorSupportUseCaseProtocol {
        CheckEmulatorSupportUseCase()
    }

    func makeLaunchEmulatorUseCase() -> LaunchEmulatorUseCaseProtocol {
        LaunchEmulatorUseCase(
            tokenProvider: TokenProvider(),
            checkEmulatorSupport: makeCheckEmulatorSupportUseCase()
        )
    }

    // MARK: - SFTP ViewModels
    
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
}
