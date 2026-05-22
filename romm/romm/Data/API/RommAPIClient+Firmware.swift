import Foundation

extension RommAPIClient {
    /// Liest die Firmware-Liste einer Plattform. ROMM liefert sie zusätzlich
    /// schon eingebettet in `PlatformSchema.firmware`; dieser Aufruf ist nur
    /// für gezielten Refresh.
    func getPlatformFirmware(platformId: Int) async throws -> [FirmwareSchema] {
        let path = withQuery("api/firmware", [("platform_id", String(platformId))])
        return try await get(path, responseType: [FirmwareSchema].self)
    }

    /// Lädt den binären Inhalt einer Firmware-Datei.
    func downloadFirmwareContent(id: Int, fileName: String) async throws -> Data {
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let path = "api/firmware/\(id)/content/\(encoded)"
        return try await get(path)
    }
}
