import Foundation

protocol PPlatformEngineSupport {
    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine>
    func preferred(for platformSlug: String) -> EmulatorEngine
}

final class PlatformEngineSupport: PPlatformEngineSupport {
    private let deltaCoreSlugs: Set<String> = ["gba"]

    private let webSupport: PCheckEmulatorSupportUseCase

    init(webSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase()) {
        self.webSupport = webSupport
    }

    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine> {
        let slug = platformSlug.lowercased()
        var result: Set<EmulatorEngine> = []
        if webSupport.execute(platformSlug: slug) { result.insert(.web) }
        if deltaCoreSlugs.contains(slug) { result.insert(.deltaCore) }
        return result
    }

    func preferred(for platformSlug: String) -> EmulatorEngine {
        let supported = supportedEngines(for: platformSlug)
        if supported.contains(.web) { return .web }
        return .deltaCore
    }
}
