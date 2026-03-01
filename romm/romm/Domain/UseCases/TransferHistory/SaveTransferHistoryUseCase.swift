import Foundation

/// Use case for saving a transfer history entry
class SaveTransferHistoryUseCase {

    private let repository: PTransferHistoryRepository

    init(repository: PTransferHistoryRepository) {
        self.repository = repository
    }

    /// Executes the use case to save a transfer history entry
    /// - Parameter transfer: The transfer history to save
    /// - Throws: An error if the save operation fails
    func execute(_ transfer: TransferHistory) throws {
        try repository.saveTransfer(transfer)
    }
}
