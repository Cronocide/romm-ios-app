import Foundation
import CoreData

/// Repository implementation for managing transfer history using Core Data
class TransferHistoryRepository: PTransferHistoryRepository {

    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - Save

    func saveTransfer(_ transfer: TransferHistory) throws {
        let entity = TransferHistoryEntity(context: context)
        entity.id = transfer.id
        entity.deviceId = transfer.deviceId
        entity.deviceName = transfer.deviceName
        entity.deviceType = transfer.deviceType.rawValue
        entity.transferType = transfer.transferType.rawValue
        entity.romId = Int64(transfer.romId)
        entity.romName = transfer.romName
        entity.platformName = transfer.platformName
        entity.platformSlug = transfer.platformSlug
        entity.fileSizeBytes = transfer.fileSizeBytes
        entity.transferDate = transfer.transferDate
        entity.success = transfer.success

        try context.save()
    }

    // MARK: - Fetch

    func getAllTransfers() throws -> [TransferHistory] {
        let request: NSFetchRequest<TransferHistoryEntity> = TransferHistoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "transferDate", ascending: false)]

        let entities = try context.fetch(request)
        return entities.compactMap { mapEntityToDomain($0) }
    }

    func getTransfersForDevice(deviceId: UUID) throws -> [TransferHistory] {
        let request: NSFetchRequest<TransferHistoryEntity> = TransferHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "transferDate", ascending: false)]

        let entities = try context.fetch(request)
        return entities.compactMap { mapEntityToDomain($0) }
    }

    func getTransfersGroupedByPlatform() throws -> [String: [TransferHistory]] {
        let allTransfers = try getAllTransfers()
        var grouped: [String: [TransferHistory]] = [:]

        for transfer in allTransfers {
            if grouped[transfer.platformName] == nil {
                grouped[transfer.platformName] = []
            }
            grouped[transfer.platformName]?.append(transfer)
        }

        return grouped
    }

    func getTransfersGroupedByPlatformForDevice(deviceId: UUID) throws -> [TransferHistoryByPlatform] {
        let transfers = try getTransfersForDevice(deviceId: deviceId)

        var grouped: [String: [TransferHistory]] = [:]

        for transfer in transfers {
            if grouped[transfer.platformName] == nil {
                grouped[transfer.platformName] = []
            }
            grouped[transfer.platformName]?.append(transfer)
        }

        // Convert to TransferHistoryByPlatform objects
        return grouped.map { platformName, transfers in
            TransferHistoryByPlatform(
                id: platformName,
                platformName: platformName,
                platformSlug: transfers.first?.platformSlug,
                transfers: transfers.sorted { $0.transferDate > $1.transferDate }
            )
        }.sorted { $0.platformName < $1.platformName }
    }

    // MARK: - Delete

    func clearAllHistory() throws {
        let request: NSFetchRequest<NSFetchRequestResult> = TransferHistoryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        try context.execute(deleteRequest)
        try context.save()
    }

    func clearHistoryForDevice(deviceId: UUID) throws {
        let request: NSFetchRequest<NSFetchRequestResult> = TransferHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId as CVarArg)

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        try context.execute(deleteRequest)
        try context.save()
    }

    // MARK: - Statistics

    func getTotalTransferCount() throws -> Int {
        let request: NSFetchRequest<TransferHistoryEntity> = TransferHistoryEntity.fetchRequest()
        return try context.count(for: request)
    }

    func getTotalTransferSize() throws -> Int64 {
        let request: NSFetchRequest<TransferHistoryEntity> = TransferHistoryEntity.fetchRequest()
        let entities = try context.fetch(request)

        return entities.reduce(0) { $0 + $1.fileSizeBytes }
    }

    // MARK: - Mapping

    private func mapEntityToDomain(_ entity: TransferHistoryEntity) -> TransferHistory? {
        guard let id = entity.id,
              let deviceId = entity.deviceId,
              let deviceName = entity.deviceName,
              let deviceTypeRaw = entity.deviceType,
              let deviceType = DeviceType(rawValue: deviceTypeRaw),
              let transferTypeRaw = entity.transferType,
              let transferType = TransferType(rawValue: transferTypeRaw),
              let romName = entity.romName,
              let platformName = entity.platformName,
              let transferDate = entity.transferDate else {
            return nil
        }

        return TransferHistory(
            id: id,
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            transferType: transferType,
            romId: Int(entity.romId),
            romName: romName,
            platformName: platformName,
            platformSlug: entity.platformSlug,
            fileSizeBytes: entity.fileSizeBytes,
            transferDate: transferDate,
            success: entity.success
        )
    }
}
