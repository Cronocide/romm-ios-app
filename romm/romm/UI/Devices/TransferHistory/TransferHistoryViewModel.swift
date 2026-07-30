import Foundation

@MainActor
class TransferHistoryViewModel: ObservableObject {

    @Published var platformGroups: [TransferHistoryByPlatform] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showingClearConfirmation = false

    private let deviceId: UUID
    private let getHistoryUseCase: GetTransferHistoryGroupedByPlatformUseCase
    private let clearHistoryUseCase: ClearTransferHistoryUseCase

    init(
        deviceId: UUID,
        factory: PDependencyFactory = DefaultDependencyFactory.shared
    ) {
        self.deviceId = deviceId
        self.getHistoryUseCase = factory.makeGetTransferHistoryGroupedByPlatformUseCase()
        self.clearHistoryUseCase = factory.makeClearTransferHistoryUseCase()
        loadHistory()
    }

    // MARK: - Public Methods

    func loadHistory() {
        isLoading = true
        error = nil

        do {
            platformGroups = try getHistoryUseCase.executeForDevice(deviceId: deviceId)
        } catch {
            self.error = "Failed to load transfer history: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func confirmClearHistory() {
        showingClearConfirmation = true
    }

    func clearHistory() {
        do {
            try clearHistoryUseCase.executeForDevice(deviceId: deviceId)
            showingClearConfirmation = false
            loadHistory()
        } catch {
            self.error = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    var hasHistory: Bool {
        !platformGroups.isEmpty
    }

    var totalTransfers: Int {
        platformGroups.reduce(0) { $0 + $1.transferCount }
    }

    var totalSize: Int64 {
        platformGroups.reduce(0) { $0 + $1.totalSize }
    }

    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
