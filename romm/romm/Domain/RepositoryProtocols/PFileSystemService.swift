import Foundation

protocol PFileSystemService {
    func fileExists(at url: URL) -> Bool
    func documentsDirectory() -> URL
    func cachesDirectory() -> URL
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func contentsOfDirectory(at url: URL, skipHidden: Bool) throws -> [URL]
    func removeItem(at url: URL) throws
    func write(_ data: Data, to url: URL) throws
}
