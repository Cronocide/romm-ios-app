import Testing
@testable import romm

struct PlatformEngineSupportTests {
    @Test func gbaSupportsBothEngines() {
        let support = PlatformEngineSupport()
        let engines = support.supportedEngines(for: "gba")
        #expect(engines.contains(.deltaCore))
        #expect(engines.contains(.web))
    }

    @Test func psxOnlySupportsWeb() {
        let support = PlatformEngineSupport()
        let engines = support.supportedEngines(for: "psx")
        #expect(engines.contains(.web))
        #expect(!engines.contains(.deltaCore))
    }

    @Test func unknownPlatformReturnsEmpty() {
        let support = PlatformEngineSupport()
        #expect(support.supportedEngines(for: "xyz").isEmpty)
    }

    @Test func preferredFallsBackToWebForGBA() {
        let support = PlatformEngineSupport()
        #expect(support.preferred(for: "gba") == .web)
    }

    @Test func slugIsCaseInsensitive() {
        let support = PlatformEngineSupport()
        #expect(support.supportedEngines(for: "GBA").contains(.deltaCore))
    }
}
