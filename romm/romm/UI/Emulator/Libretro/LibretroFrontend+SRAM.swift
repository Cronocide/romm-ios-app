import Foundation

extension LibretroFrontend {

    // MARK: - SRAM (memory card / battery) persistence

    func sramBuffer() -> UnsafeMutableRawBufferPointer? {
        guard let dataFn = retro_get_memory_data, let sizeFn = retro_get_memory_size else { return nil }
        let size = sizeFn(LibretroABI.MEMORY_SAVE_RAM)
        guard size > 0, let base = dataFn(LibretroABI.MEMORY_SAVE_RAM) else { return nil }
        return UnsafeMutableRawBufferPointer(start: base, count: size)
    }

    func loadSRAMFromDisk() {
        guard let url = sramURL, let buf = sramBuffer() else { return }
        guard let data = try? Data(contentsOf: url) else {
            print("[Libretro] SRAM: no existing file at \(url.lastPathComponent), starting blank (\(buf.count) bytes)")
            return
        }
        let n = min(data.count, buf.count)
        data.copyBytes(to: buf.bindMemory(to: UInt8.self).baseAddress!, count: n)
        print("[Libretro] SRAM: loaded \(n) bytes from \(url.lastPathComponent)")
    }

    func writeSRAMToDisk() {
        guard let url = sramURL, let buf = sramBuffer() else { return }
        let data = Data(bytes: buf.baseAddress!, count: buf.count)
        do {
            try data.write(to: url, options: .atomic)
            print("[Libretro] SRAM: wrote \(data.count) bytes to \(url.lastPathComponent)")
        } catch {
            print("[Libretro] SRAM: write failed: \(error)")
        }
    }
}
