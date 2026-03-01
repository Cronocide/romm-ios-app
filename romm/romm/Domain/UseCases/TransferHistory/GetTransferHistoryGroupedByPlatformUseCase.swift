import Foundation

/// Use case for retrieving transfer history grouped by platform
class GetTransferHistoryGroupedByPlatformUseCase {

    private let repository: PTransferHistoryRepository

    init(repository: PTransferHistoryRepository) {
        self.repository = repository
    }

    /// Gets transfer history grouped by platform
    /// - Returns: Dictionary with platform names as keys
    func execute() throws -> [String: [TransferHistory]] {
        return try repository.getTransfersGroupedByPlatform()
    }

    /// Gets transfer history grouped by platform for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Returns: Array of TransferHistoryByPlatform objects
    func executeForDevice(deviceId: UUID) throws -> [TransferHistoryByPlatform] {
        return try repository.getTransfersGroupedByPlatformForDevice(deviceId: deviceId)
    }
}
