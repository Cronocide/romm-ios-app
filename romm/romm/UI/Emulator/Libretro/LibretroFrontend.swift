import Foundation
import Darwin
import AVFoundation

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
    private var runTimerSuspended: Bool = false
    fileprivate var frameCount: UInt64 = 0

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
    private var retro_get_memory_data: LibretroABI.RetroGetMemoryData?
    private var retro_get_memory_size: LibretroABI.RetroGetMemorySize?

    private var sramURL: URL?

    weak var videoSink: LibretroVideoSink?

    // MARK: - Input state (Joypad port 0)
    /// Index = JoypadButton.rawValue. Atomar via MainActor-Isolation.
    fileprivate var buttonState: [Bool] = Array(repeating: false, count: 16)

    func setButton(_ button: LibretroABI.JoypadButton, pressed: Bool) {
        buttonState[Int(button.rawValue)] = pressed
    }

    func clearAllButtons() {
        for i in 0..<buttonState.count { buttonState[i] = false }
    }

    // MARK: - Audio
    private let audioEngine = AVAudioEngine()
    private var audioSourceNode: AVAudioSourceNode?
    /// Shared ringbuffer + idx werden vom Audio-Thread (renderAudio) und MainActor
    /// (enqueueAudio) gemeinsam genutzt. NSLock schützt vor Race.
    nonisolated(unsafe) fileprivate static let audioRingLock = NSLock()
    nonisolated(unsafe) fileprivate static var audioRing: [Int16] = Array(repeating: 0, count: 44100 * 2 * 2)
    nonisolated(unsafe) fileprivate static var audioWriteIdx: Int = 0
    nonisolated(unsafe) fileprivate static var audioReadIdx: Int = 0

    fileprivate func startAudio(sampleRate: Double) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            return Self.renderAudio(into: abl, frameCount: Int(frameCount))
        }
        audioSourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
            print("[Libretro] audio engine started @\(sampleRate)Hz")
        } catch {
            print("[Libretro] audio start failed: \(error)")
        }
    }

    fileprivate func stopAudio() {
        audioEngine.stop()
        if let node = audioSourceNode {
            audioEngine.detach(node)
            audioSourceNode = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    fileprivate func enqueueAudio(_ samples: UnsafePointer<Int16>, frames: Int) {
        let count = frames * 2 // stereo
        Self.audioRingLock.lock()
        for i in 0..<count {
            Self.audioRing[Self.audioWriteIdx] = samples[i]
            Self.audioWriteIdx = (Self.audioWriteIdx + 1) % Self.audioRing.count
            if Self.audioWriteIdx == Self.audioReadIdx {
                Self.audioReadIdx = (Self.audioReadIdx + 1) % Self.audioRing.count
            }
        }
        Self.audioRingLock.unlock()
    }

    nonisolated private static func renderAudio(into abl: UnsafeMutableAudioBufferListPointer, frameCount: Int) -> OSStatus {
        let left = abl[0].mData!.assumingMemoryBound(to: Float.self)
        let right = abl.count > 1 ? abl[1].mData!.assumingMemoryBound(to: Float.self) : nil
        let interleaved = right == nil

        audioRingLock.lock()
        if interleaved {
            let needed = frameCount * 2
            var i = 0
            while i < needed && audioReadIdx != audioWriteIdx {
                left[i] = Float(audioRing[audioReadIdx]) / 32768.0
                audioReadIdx = (audioReadIdx + 1) % audioRing.count
                i += 1
            }
            while i < needed { left[i] = 0; i += 1 }
        } else {
            var fi = 0
            while fi < frameCount && audioReadIdx != audioWriteIdx {
                left[fi] = Float(audioRing[audioReadIdx]) / 32768.0
                audioReadIdx = (audioReadIdx + 1) % audioRing.count
                if audioReadIdx == audioWriteIdx { right![fi] = 0; fi += 1; break }
                right![fi] = Float(audioRing[audioReadIdx]) / 32768.0
                audioReadIdx = (audioReadIdx + 1) % audioRing.count
                fi += 1
            }
            while fi < frameCount { left[fi] = 0; right![fi] = 0; fi += 1 }
        }
        audioRingLock.unlock()
        return noErr
    }

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

        let romBase = (gamePath as NSString).lastPathComponent
        let stem = (romBase as NSString).deletingPathExtension
        self.sramURL = URL(fileURLWithPath: saveDir).appendingPathComponent("\(stem).srm")
        loadSRAMFromDisk()

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

        startAudio(sampleRate: av.timing.sample_rate > 0 ? av.timing.sample_rate : 44100)
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
        self.runTimerSuspended = false
    }

    func stop() {
        guard handle != nil else { return }
        if let timer = runTimer {
            // DispatchSourceTimer crasht beim cancel() im suspendierten Zustand.
            if runTimerSuspended { timer.resume(); runTimerSuspended = false }
            timer.cancel()
        }
        runTimer = nil
        stopAudio()
        clearAllButtons()
        writeSRAMToDisk()
        sramURL = nil
        retro_unload_game?()
        retro_deinit?()
        if let h = handle {
            dlclose(h)
            handle = nil
        }
        // Drop stale C function pointers into the now-unmapped dylib so a
        // delayed pause/resume from a stray scenePhase callback can't jump
        // into freed text segments.
        retro_init = nil; retro_deinit = nil
        retro_get_system_info = nil; retro_get_system_av_info = nil
        retro_set_environment = nil; retro_set_video_refresh = nil
        retro_set_audio_sample = nil; retro_set_audio_sample_batch = nil
        retro_set_input_poll = nil; retro_set_input_state = nil
        retro_set_controller_port_device = nil
        retro_run = nil; retro_reset = nil
        retro_load_game = nil; retro_unload_game = nil
        retro_serialize_size = nil; retro_serialize = nil; retro_unserialize = nil
        retro_get_memory_data = nil; retro_get_memory_size = nil
    }

    func pause() {
        guard handle != nil else { return }
        guard !runTimerSuspended, let timer = runTimer else { return }
        timer.suspend()
        runTimerSuspended = true
        clearAllButtons()
        audioEngine.pause()
        writeSRAMToDisk()
    }

    func resume() {
        guard handle != nil else { return }
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        guard runTimerSuspended, let timer = runTimer else { return }
        timer.resume()
        runTimerSuspended = false
    }

    // MARK: - Save / Load state

    func saveStateData() -> Data? {
        guard let sizeFn = retro_serialize_size, let serFn = retro_serialize else { return nil }
        let size = sizeFn()
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            return serFn(base, size)
        }
        return ok ? data : nil
    }

    func loadStateData(_ data: Data) -> Bool {
        guard let unserFn = retro_unserialize else { return false }
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            return unserFn(base, data.count)
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
        retro_get_memory_data            = try? sym("retro_get_memory_data")
        retro_get_memory_size            = try? sym("retro_get_memory_size")
    }

    // MARK: - SRAM (memory card / battery) persistence

    private func sramBuffer() -> UnsafeMutableRawBufferPointer? {
        guard let dataFn = retro_get_memory_data, let sizeFn = retro_get_memory_size else { return nil }
        let size = sizeFn(LibretroABI.MEMORY_SAVE_RAM)
        guard size > 0, let base = dataFn(LibretroABI.MEMORY_SAVE_RAM) else { return nil }
        return UnsafeMutableRawBufferPointer(start: base, count: size)
    }

    fileprivate func loadSRAMFromDisk() {
        guard let url = sramURL, let buf = sramBuffer() else { return }
        guard let data = try? Data(contentsOf: url) else {
            print("[Libretro] SRAM: no existing file at \(url.lastPathComponent), starting blank (\(buf.count) bytes)")
            return
        }
        let n = min(data.count, buf.count)
        data.copyBytes(to: buf.bindMemory(to: UInt8.self).baseAddress!, count: n)
        print("[Libretro] SRAM: loaded \(n) bytes from \(url.lastPathComponent)")
    }

    fileprivate func writeSRAMToDisk() {
        guard let url = sramURL, let buf = sramBuffer() else { return }
        let data = Data(bytes: buf.baseAddress!, count: buf.count)
        do {
            try data.write(to: url, options: .atomic)
            print("[Libretro] SRAM: wrote \(data.count) bytes to \(url.lastPathComponent)")
        } catch {
            print("[Libretro] SRAM: write failed: \(error)")
        }
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
            let s = LibretroFrontend.shared
            s.frameCount &+= 1
            if s.frameCount <= 5 || s.frameCount % 60 == 0 {
                print("[Libretro] frame #\(s.frameCount) data=\(data != nil ? "ptr" : "nil") \(width)x\(height) pitch=\(pitch) fmt=\(s.pixelFormat)")
            }
            s.videoSink?.libretroDidProduceFrame(
                data: data, width: width, height: height, pitch: pitch,
                pixelFormat: s.pixelFormat
            )
        }
    }

    private static let audioSampleCallback: LibretroABI.AudioSampleFn = { left, right in
        var pair: [Int16] = [left, right]
        pair.withUnsafeBufferPointer { buf in
            MainActor.assumeIsolated {
                LibretroFrontend.shared.enqueueAudio(buf.baseAddress!, frames: 1)
            }
        }
    }

    private static let audioBatchCallback: LibretroABI.AudioSampleBatchFn = { data, frames in
        guard let data = data else { return frames }
        MainActor.assumeIsolated {
            LibretroFrontend.shared.enqueueAudio(data, frames: frames)
        }
        return frames
    }

    private static let inputPollCallback: LibretroABI.InputPollFn = { }

    private static let inputStateCallback: LibretroABI.InputStateFn = { port, device, _, id in
        guard port == 0, device == LibretroABI.DEVICE_JOYPAD, id < 16 else { return 0 }
        return MainActor.assumeIsolated {
            LibretroFrontend.shared.buttonState[Int(id)] ? 1 : 0
        }
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
            // pcsx_rearmed default `pcsx_rearmed_memcard1 = "disabled"` means the core
            // never allocates the SAVE_RAM buffer -- so retro_get_memory_size(0) returns
            // 0 and our .srm load/save is a silent no-op. Forcing "libretro" enables
            // the frontend-managed memory card path.
            guard let data = data else { return false }
            let v = data.assumingMemoryBound(to: LibretroABI.Variable.self)
            guard let keyPtr = v.pointee.key else { v.pointee.value = nil; return false }
            let key = String(cString: keyPtr)
            let answer: String?
            switch key {
            case "pcsx_rearmed_memcard1": answer = "libretro"
            case "pcsx_rearmed_memcard2": answer = "disabled"
            default: answer = nil
            }
            if let answer = answer {
                v.pointee.value = UnsafePointer(Self.cachedCString(answer))
                return true
            }
            v.pointee.value = nil
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
    fileprivate static func cachedCString(_ value: String) -> UnsafeMutablePointer<CChar> {
        if let existing = cStringStorage[value] { return existing }
        let ptr = strdup(value)!
        cStringStorage[value] = ptr
        return ptr
    }
    private func writeCString(_ value: String, into data: UnsafeMutableRawPointer?) {
        guard let data = data else { return }
        let ptr = Self.cachedCString(value)
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
