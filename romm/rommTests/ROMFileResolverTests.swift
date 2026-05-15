import Testing
import Foundation
@testable import romm

struct ROMFileResolverTests {

    private func makeROM(files: [String]) -> DownloadedROM {
        DownloadedROM(
            id: 1, name: "Test", platformName: "Game Boy Advance",
            platformSlug: "gba", downloadedAt: Date(), totalSizeBytes: 0,
            localDirectory: "rom1",
            files: files.map { DownloadedROMFile(fileName: $0, fileSizeBytes: 0) }
        )
    }

    @Test func picksGBAExtension() throws {
        let rom = makeROM(files: ["readme.txt", "Game.gba"])
        let resolver = ROMFileResolver()
        let url = try resolver.resolve(rom: rom, baseURL: URL(fileURLWithPath: "/tmp"), gameType: .gba)
        #expect(url.lastPathComponent == "Game.gba")
    }

    @Test func throwsWhenNoMatch() {
        let rom = makeROM(files: ["readme.txt"])
        let resolver = ROMFileResolver()
        #expect(throws: ROMFileResolverError.self) {
            _ = try resolver.resolve(rom: rom, baseURL: URL(fileURLWithPath: "/tmp"), gameType: .gba)
        }
    }
}
