import Foundation

/// Use case for clearing transfer history
class ClearTransferHistoryUseCase {

    private let repository: PTransferHistoryRepository

    init(repository: PTransferHistoryRepository) {
        self.repository = repository
    }

    /// Clears all transfer history
    /// - Throws: An error if the clear operation fails
    func execute() throws {
        try repository.clearAllHistory()
    }

    /// Clears transfer history for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Throws: An error if the clear operation fails
    func executeForDevice(deviceId: UUID) throws {
        try repository.clearHistoryForDevice(deviceId: deviceId)
    }
}
