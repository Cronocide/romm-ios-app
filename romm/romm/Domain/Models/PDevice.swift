import Foundation

/// Protocol that defines common properties and behaviors for all device types
/// (both local devices and remote SFTP connections)
protocol PDevice: Identifiable, Equatable {
    /// Unique identifier for the device
    var id: UUID { get }

    /// Display name of the device (e.g., "My iPhone", "Nintendo Switch")
    var name: String { get }

    /// Type of device (local or SFTP)
    var deviceType: DeviceType { get }

    /// Whether this device is set as the default for uploads/downloads
    var isDefault: Bool { get }

    /// Last time this device was successfully connected/accessed
    var lastConnectedAt: Date? { get }

    /// When this device configuration was created
    var createdAt: Date { get }

    /// When this device configuration was last updated
    var updatedAt: Date { get }
}

/// Enum to distinguish between different device types
enum DeviceType: String, Codable, CaseIterable {
    /// Local device (this iPhone/iPad)
    case local = "local"

    /// Remote device connected via SFTP
    case sftp = "sftp"

    var displayName: String {
        switch self {
        case .local:
            return "This Device"
        case .sftp:
            return "Remote Device"
        }
    }

    var icon: String {
        switch self {
        case .local:
            return "iphone"
        case .sftp:
            return "server.rack"
        }
    }
}
