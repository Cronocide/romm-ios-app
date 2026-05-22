import Foundation
import Darwin
import UIKit

/// Minimaler libretro-Frontend: dlopen + Symbolauflösung + Run-Loop.
///
/// Implementiert die 5 Core-Callbacks als statische C-Funktionspointer, die
/// auf einen Singleton (`LibretroFrontend.shared`) zurückrouten. Singleton
/// ist nötig, weil `@convention(c)` keine Closure-Captures erlaubt — libretro
/// gibt uns keinen userdata-Pointer in `retro_set_environment`.
///
/// Status: PCSX ReARMed Bring-Up. Video als RGB565/XRGB8888 Software-Blit auf
/// ein CALayer (siehe `LibretroVideoView`). Audio TODO. Input TODO.
@MainActor
final class LibretroFrontend {

    // MARK: - Singleton (für C-Callbacks)
    static let shared = LibretroFrontend()
    private init() {}

    // MARK: - State
    private var handle: UnsafeMutableRawPointer?
    private var avInfo = LibretroABI.SystemAVInfo(
        geometry: .init(base_width: 0, base_height: 0, max_width: 0, max_height: 0, aspect_ratio: 0),
        timing: .init(fps: 60, sample_rate: 44100)
    )
    private var pixelFormat: LibretroABI.PixelFormat = .rgb1555
    private var systemDir: String = ""
    private var saveDir: String = ""
    private var runTimer: DispatchSourceTimer?

    // Symbols
    private var retro_init: LibretroABI.RetroInit?
    private var retro_deinit: LibretroABI.RetroDeinit?
    private var retro_get_system_info: LibretroABI.RetroGetSystemInfo?
    private var retro_get_system_av_info: LibretroABI.RetroGetSystemAVInfo?
    private var retro_set_environment: LibretroABI.RetroSetEnvironment?
    private var retro_set_video_refresh: LibretroABI.RetroSetVideoRefresh?
    private var retro_set_audio_sample: LibretroABI.RetroSetAudioSample?
    private var retro_set_audio_sample_batch: LibretroABI.RetroSetAudioSampleBatch?
    private var retro_set_input_poll: LibretroABI.RetroSetInputPoll?
    private var retro_set_input_state: LibretroABI.RetroSetInputState?
    private var retro_set_controller_port_device: LibretroABI.RetroSetControllerPortDevice?
    private var retro_run: LibretroABI.RetroRun?
    private var retro_reset: LibretroABI.RetroReset?
    private var retro_load_game: LibretroABI.RetroLoadGame?
    private var retro_unload_game: LibretroABI.RetroUnloadGame?
    private var retro_serialize_size: LibretroABI.RetroSerializeSize?
    private var retro_serialize: LibretroABI.RetroSerialize?
    private var retro_unserialize: LibretroABI.RetroUnserialize?

    weak var videoSink: LibretroVideoSink?

    // MARK: - Public API

    enum FrontendError: LocalizedError {
        case dylibNotFound(String)
        case symbolMissing(String)
        case loadGameFailed

        var errorDescription: String? {
            switch self {
            case .dylibNotFound(let path): return "Dylib nicht gefunden: \(path)"
            case .symbolMissing(let name): return "Libretro-Symbol fehlt: \(name)"
            case .loadGameFailed: return "retro_load_game ist fehlgeschlagen."
            }
        }
    }

    func load(corePath: String, gamePath: String, systemDir: String, saveDir: String) throws {
        guard FileManager.default.fileExists(atPath: corePath) else {
            throw FrontendError.dylibNotFound(corePath)
        }
        try? FileManager.default.createDirectory(atPath: systemDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: saveDir, withIntermediateDirectories: true)
        self.systemDir = systemDir
        self.saveDir = saveDir

        guard let h = dlopen(corePath, RTLD_NOW | RTLD_LOCAL) else {
            let err = String(cString: dlerror())
            throw FrontendError.dylibNotFound("\(corePath) – \(err)")
        }
        self.handle = h

        try resolveSymbols()

        retro_set_environment?(Self.envCallback)
        retro_set_video_refresh?(Self.videoRefreshCallback)
        retro_set_audio_sample?(Self.audioSampleCallback)
        retro_set_audio_sample_batch?(Self.audioBatchCallback)
        retro_set_input_poll?(Self.inputPollCallback)
        retro_set_input_state?(Self.inputStateCallback)

        retro_init?()

        // need_fullpath: pcsx_rearmed = true => path-only reicht.
        // Wichtig: cPath nur innerhalb von withCString gültig.
        let loaded: Bool = gamePath.withCString { cPath in
            var info = LibretroABI.GameInfo(path: cPath, data: nil, size: 0, meta: nil)
            return withUnsafePointer(to: &info) { ptr in
                retro_load_game?(UnsafeRawPointer(ptr)) ?? false
            }
        }
        guard loaded else { throw FrontendError.loadGameFailed }

        var av = LibretroABI.SystemAVInfo(
            geometry: .init(base_width: 0, base_height: 0, max_width: 0, max_height: 0, aspect_ratio: 0),
            timing: .init(fps: 60, sample_rate: 44100)
        )
        withUnsafeMutablePointer(to: &av) { ptr in
            retro_get_system_av_info?(UnsafeMutableRawPointer(ptr))
        }
        self.avInfo = av
        print("[Libretro] AV: \(av.geometry.base_width)x\(av.geometry.base_height) @\(av.timing.fps)Hz audio=\(av.timing.sample_rate)Hz")

        retro_set_controller_port_device?(0, LibretroABI.DEVICE_JOYPAD)
    }

    func startRunLoop() {
        let fps = avInfo.timing.fps > 0 ? avInfo.timing.fps : 60
        let interval = 1.0 / fps
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.retro_run?()
        }
        timer.resume()
        self.runTimer = timer
    }

    func stop() {
        runTimer?.cancel()
        runTimer = nil
        retro_unload_game?()
        retro_deinit?()
        if let h = handle {
            dlclose(h)
            handle = nil
        }
    }

    // MARK: - Symbol resolution

    private func resolveSymbols() throws {
        retro_init                       = try sym("retro_init")
        retro_deinit                     = try sym("retro_deinit")
        retro_get_system_info            = try sym("retro_get_system_info")
        retro_get_system_av_info         = try sym("retro_get_system_av_info")
        retro_set_environment            = try sym("retro_set_environment")
        retro_set_video_refresh          = try sym("retro_set_video_refresh")
        retro_set_audio_sample           = try sym("retro_set_audio_sample")
        retro_set_audio_sample_batch     = try sym("retro_set_audio_sample_batch")
        retro_set_input_poll             = try sym("retro_set_input_poll")
        retro_set_input_state            = try sym("retro_set_input_state")
        retro_set_controller_port_device = try sym("retro_set_controller_port_device")
        retro_run                        = try sym("retro_run")
        retro_reset                      = try? sym("retro_reset")
        retro_load_game                  = try sym("retro_load_game")
        retro_unload_game                = try sym("retro_unload_game")
        retro_serialize_size             = try? sym("retro_serialize_size")
        retro_serialize                  = try? sym("retro_serialize")
        retro_unserialize                = try? sym("retro_unserialize")
    }

    private func sym<T>(_ name: String) throws -> T {
        guard let raw = dlsym(handle, name) else {
            throw FrontendError.symbolMissing(name)
        }
        return unsafeBitCast(raw, to: T.self)
    }

    // MARK: - Static C callbacks

    private static let envCallback: LibretroABI.EnvironmentFn = { cmd, data in
        return MainActor.assumeIsolated { LibretroFrontend.shared.handleEnv(cmd: cmd, data: data) }
    }

    private static let videoRefreshCallback: LibretroABI.VideoRefreshFn = { data, width, height, pitch in
        MainActor.assumeIsolated {
            LibretroFrontend.shared.videoSink?.libretroDidProduceFrame(
                data: data, width: width, height: height, pitch: pitch,
                pixelFormat: LibretroFrontend.shared.pixelFormat
            )
        }
    }

    private static let audioSampleCallback: LibretroABI.AudioSampleFn = { _, _ in
        // TODO: AudioEngine
    }

    private static let audioBatchCallback: LibretroABI.AudioSampleBatchFn = { _, frames in
        // TODO: AudioEngine
        return frames
    }

    private static let inputPollCallback: LibretroABI.InputPollFn = { }

    private static let inputStateCallback: LibretroABI.InputStateFn = { _, _, _, _ in
        // TODO: Input
        return 0
    }

    // MARK: - Environment dispatch

    private func handleEnv(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        switch cmd {
        case LibretroABI.ENVIRONMENT_GET_OVERSCAN, LibretroABI.ENVIRONMENT_GET_CAN_DUPE:
            data?.assumingMemoryBound(to: Bool.self).pointee = true
            return true

        case LibretroABI.ENVIRONMENT_SET_PIXEL_FORMAT:
            guard let raw = data?.assumingMemoryBound(to: Int32.self).pointee,
                  let pf = LibretroABI.PixelFormat(rawValue: raw) else { return false }
            self.pixelFormat = pf
            print("[Libretro] pixel format: \(pf)")
            return true

        case LibretroABI.ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            writeCString(systemDir, into: data)
            return true

        case LibretroABI.ENVIRONMENT_GET_SAVE_DIRECTORY:
            writeCString(saveDir, into: data)
            return true

        case LibretroABI.ENVIRONMENT_GET_VARIABLE_UPDATE:
            data?.assumingMemoryBound(to: Bool.self).pointee = false
            return true

        case LibretroABI.ENVIRONMENT_GET_VARIABLE:
            // Core fragt nach Option-Wert. Wir liefern noch keine -> NULL.
            data?.assumingMemoryBound(to: LibretroABI.Variable.self).pointee.value = nil
            return false

        case LibretroABI.ENVIRONMENT_SET_PERFORMANCE_LEVEL,
             LibretroABI.ENVIRONMENT_SET_VARIABLES,
             LibretroABI.ENVIRONMENT_SET_INPUT_DESCRIPTORS,
             LibretroABI.ENVIRONMENT_SET_MESSAGE:
            return true

        default:
            // print("[Libretro] unhandled env cmd: \(cmd)")
            return false
        }
    }

    // C-Strings ablegen, sodass libretro sie referenzieren kann.
    nonisolated(unsafe) private static var cStringStorage: [String: UnsafeMutablePointer<CChar>] = [:]
    private func writeCString(_ value: String, into data: UnsafeMutableRawPointer?) {
        guard let data = data else { return }
        let ptr: UnsafeMutablePointer<CChar>
        if let existing = Self.cStringStorage[value] {
            ptr = existing
        } else {
            ptr = strdup(value)
            Self.cStringStorage[value] = ptr
        }
        data.assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee = UnsafePointer(ptr)
    }
}

// MARK: - Video sink

@MainActor
protocol LibretroVideoSink: AnyObject {
    func libretroDidProduceFrame(
        data: UnsafeRawPointer?,
        width: UInt32,
        height: UInt32,
        pitch: Int,
        pixelFormat: LibretroABI.PixelFormat
    )
}
