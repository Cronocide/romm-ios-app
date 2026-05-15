import Testing
@testable import romm

struct PlatformSlugToGameTypeTests {
    @Test func gbaMaps() { #expect(PlatformSlugToGameType.map("gba") == .gba) }
    @Test func gbaUppercaseMaps() { #expect(PlatformSlugToGameType.map("GBA") == .gba) }
    @Test func unknownReturnsNil() { #expect(PlatformSlugToGameType.map("psx") == nil) }
}
