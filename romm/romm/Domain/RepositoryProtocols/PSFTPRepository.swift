import Foundation
import Combine

protocol PSFTPRepository {
    func getAllConnections() -> [SFTPConnection]
    func getConnection(by id: UUID) -> SFTPConnection?
    func saveConnection(_ connection: SFTPConnection, credentials: SFTPCredentials) throws
    func deleteConnection(_ connection: SFTPConnection) throws
    func setDefaultConnection(_ connection: SFTPConnection) throws
    func getDefaultConnection() -> SFTPConnection?
    func getCredentials(for connectionId: UUID) -> SFTPCredentials?
    
    func getFavoriteDirectories(for connectionId: UUID) -> [String]
    func addFavoriteDirectory(_ path: String, for connectionId: UUID) throws
    func removeFavoriteDirectory(_ path: String, for connectionId: UUID) throws
}
