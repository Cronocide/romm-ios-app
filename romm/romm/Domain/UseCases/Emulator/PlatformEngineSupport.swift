import Foundation

protocol PPlatformEngineSupport {
    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine>
    func preferred(for platformSlug: String) -> EmulatorEngine
}

final class PlatformEngineSupport: PPlatformEngineSupport {
    private let webSupport: PCheckEmulatorSupportUseCase

    init(webSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase()) {
        self.webSupport = webSupport
    }

    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine> {
        let slug = platformSlug.lowercased()
        var result: Set<EmulatorEngine> = []
        if webSupport.execute(platformSlug: slug) { result.insert(.web) }
        if PlatformSlugToGameType.map(slug) != nil || PlatformSlugToLibretroCore.map(slug) != nil {
            result.insert(.native)
        }
        return result
    }

    func preferred(for platformSlug: String) -> EmulatorEngine {
        let supported = supportedEngines(for: platformSlug)
        if supported.contains(.web) { return .web }
        return .native
    }
}
