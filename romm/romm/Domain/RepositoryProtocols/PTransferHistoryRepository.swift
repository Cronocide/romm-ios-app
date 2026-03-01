import Foundation

/// Protocol for managing transfer history (uploads and downloads)
protocol PTransferHistoryRepository {
    /// Saves a transfer record to history
    /// - Parameter transfer: The transfer history entry to save
    /// - Throws: An error if the save operation fails
    func saveTransfer(_ transfer: TransferHistory) throws

    /// Gets all transfer history entries, sorted by date (newest first)
    /// - Returns: Array of all transfer history entries
    func getAllTransfers() throws -> [TransferHistory]

    /// Gets transfer history for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Returns: Array of transfer history entries for the device
    func getTransfersForDevice(deviceId: UUID) throws -> [TransferHistory]

    /// Gets transfer history grouped by platform
    /// - Returns: Dictionary with platform names as keys and arrays of transfers as values
    func getTransfersGroupedByPlatform() throws -> [String: [TransferHistory]]

    /// Gets transfer history grouped by platform for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Returns: Array of TransferHistoryByPlatform objects
    func getTransfersGroupedByPlatformForDevice(deviceId: UUID) throws -> [TransferHistoryByPlatform]

    /// Clears all transfer history
    /// - Throws: An error if the clear operation fails
    func clearAllHistory() throws

    /// Clears transfer history for a specific device
    /// - Parameter deviceId: The UUID of the device
    /// - Throws: An error if the clear operation fails
    func clearHistoryForDevice(deviceId: UUID) throws

    /// Gets the total number of transfers
    /// - Returns: Total count of transfer history entries
    func getTotalTransferCount() throws -> Int

    /// Gets the total size of all transfers
    /// - Returns: Total size in bytes
    func getTotalTransferSize() throws -> Int64
}
