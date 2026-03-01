import Foundation

/// Use case for retrieving transfer history
class GetTransferHistoryUseCase {

    private let repository: PTransferHistoryRepository

    init(repository: PTransferHistoryRepository) {
        self.repository = repository
    }

    /// Gets all transfer history entries
    /// - Returns: Array of all transfer history, sorted by date (newest first)
    func execute() throws -> [TransferHistory] {
        return try repository.getAllTransfers()
    }

    /// Gets transfer history for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Returns: Array of transfer history for the device
    func executeForDevice(deviceId: UUID) throws -> [TransferHistory] {
        return try repository.getTransfersForDevice(deviceId: deviceId)
    }
}
