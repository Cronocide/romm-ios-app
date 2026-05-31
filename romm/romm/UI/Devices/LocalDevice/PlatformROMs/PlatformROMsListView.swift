import SwiftUI

/// Shows list of ROMs for a specific platform
struct PlatformROMsListView: View {
    let platformName: String
    /// Read reactively from the parent's @Observable view model so the list
    /// updates after a delete — passing a snapshot `[DownloadedROM]` left the
    /// pushed detail view stuck on stale data while the parent reloaded.
    let viewModel: LocalDeviceDetailViewModel
    let onDelete: (DownloadedROM) -> Void

    private var roms: [DownloadedROM] {
        viewModel.romsByPlatform[platformName] ?? []
    }

    @State private var launchDecision: LaunchDecision?
    @State private var launchingRomId: Int?
    @State private var romPendingDelete: DownloadedROM?
    private let launchUseCase: PLaunchEmulatorUseCase = DefaultDependencyFactory.shared.makeLaunchEmulatorUseCase()

    var body: some View {
        List {
            ForEach(roms) { rom in
                Button {
                    // Tap to play (if supported)
                    if isPlatformSupported(rom.platformSlug) && launchingRomId == nil {
                        launchingRomId = rom.id
                        Task { await launch(rom: rom) }
                    }
                } label: {
                    ROMInfoView(
                        rom: rom,
                        isPlayable: isPlatformSupported(rom.platformSlug),
                        isLaunching: launchingRomId == rom.id
                    )
                }
                .buttonStyle(.plain)
                .disabled(launchingRomId != nil && launchingRomId != rom.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        romPendingDelete = rom
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    ShareSwipeButton(rom: rom)
                }
            }
        }
        .navigationTitle(platformName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $launchDecision, onDismiss: {
            launchingRomId = nil
            OrientationLock.set(.portrait, rotateTo: .portrait)
        }) { decision in
            EmulatorRouterView(decision: decision)
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "Delete ROM?",
            isPresented: Binding(
                get: { romPendingDelete != nil },
                set: { if !$0 { romPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: romPendingDelete
        ) { rom in
            Button("Delete \(rom.name)", role: .destructive) {
                onDelete(rom)
                romPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { romPendingDelete = nil }
        } message: { rom in
            Text("This will remove all files (\(rom.formattedSize)).")
        }
    }

    private func launch(rom: DownloadedROM) async {
        let start = Date()
        let result = await launchUseCase.execute(rom: rom.toRom())
        let elapsed = Date().timeIntervalSince(start)
        let minVisible: TimeInterval = 0.45
        if elapsed < minVisible {
            try? await Task.sleep(nanoseconds: UInt64((minVisible - elapsed) * 1_000_000_000))
        }
        if case .success(let decision) = result {
            launchDecision = decision
        } else {
            launchingRomId = nil
        }
    }

    /// Check if platform is supported by EmulatorJS
    private func isPlatformSupported(_ platformSlug: String) -> Bool {
        let supportedPlatforms: Set<String> = [
            // Nintendo
            "nes", "snes", "n64", "gba", "gbc", "gb", "nds",
            // Sega
            "genesis", "megadrive", "mastersystem", "gamegear", "saturn", "dreamcast",
            // Sony
            "psx", "ps1", "playstation", "psp",
            // Other
            "arcade"
        ]

        return supportedPlatforms.contains { platformSlug.lowercased().contains($0) }
    }
}

/// ROM information display (non-interactive)
private struct ROMInfoView: View {
    let rom: DownloadedROM
    let isPlayable: Bool
    var isLaunching: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rom.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(rom.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(rom.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if rom.files.count > 1 {
                    Text("\(rom.files.count) files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isLaunching {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.green)
                    .frame(width: 24, height: 24)
            } else if isPlayable {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isLaunching ? 0.7 : 1)
    }
}

/// Share swipe action button
private struct ShareSwipeButton: View {
    let rom: DownloadedROM
    @State private var shareSheetItem: ShareSheetItem?
    @State private var showFileNotFoundAlert = false
    @State private var temporaryShareDirectory: URL?

    var body: some View {
        Button {
            let (files, tempDir) = getROMFiles()
            if files.isEmpty {
                showFileNotFoundAlert = true
            } else {
                temporaryShareDirectory = tempDir
                shareSheetItem = ShareSheetItem(urls: files)
                print("🎯 Created ShareSheetItem with \(files.count) URLs")
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .tint(.blue)
        .sheet(item: $shareSheetItem, onDismiss: cleanupTemporaryFiles) { item in
            let _ = print("📋 Sheet presenting with \(item.urls.count) items:")
            let _ = item.urls.forEach { print("   - \($0.lastPathComponent)") }

            ShareSheet(activityItems: item.urls)
        }
        .alert("Files Not Found", isPresented: $showFileNotFoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The ROM files could not be found on this device. They may have been deleted or moved.")
        }
    }

    // MARK: - File Sharing Logic

    private func getROMFiles() -> (files: [URL], tempDirectory: URL?) {
        let romsBaseURL = LocalROMRepository().romsBaseURL
        let fileManager = FileManager.default
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

        let shareDirectory = tempDirectory.appendingPathComponent("ROMShare-\(UUID().uuidString)")
        try? fileManager.createDirectory(at: shareDirectory, withIntermediateDirectories: true)

        var temporaryFileURLs: [URL] = []

        print("🔍 Searching for ROM files: \(rom.name)")
        print("   Stored path: \(rom.localDirectory)")

        var romDirectoryURL = romsBaseURL.appendingPathComponent(rom.localDirectory)

        if !fileManager.fileExists(atPath: romDirectoryURL.path) {
            print("⚠️ Stored path doesn't exist, searching all platforms...")
            if let actualPath = findActualROMPath(romsBaseURL: romsBaseURL, romName: rom.name, fileManager: fileManager) {
                romDirectoryURL = actualPath
                print("✅ Found ROM at: \(actualPath.path)")
            } else {
                print("❌ ROM directory not found anywhere")
                return ([], nil)
            }
        }

        for file in rom.files {
            let sourceURL = romDirectoryURL.appendingPathComponent(file.fileName)
            let destinationURL = shareDirectory.appendingPathComponent(file.fileName)

            if fileManager.fileExists(atPath: sourceURL.path) {
                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destinationURL.path)
                    temporaryFileURLs.append(destinationURL)
                    print("✅ Copied for sharing: \(file.fileName)")
                } catch {
                    print("❌ Failed to copy file for sharing: \(error)")
                }
            } else {
                print("⚠️ Source file doesn't exist: \(sourceURL.path)")
            }
        }

        if !temporaryFileURLs.isEmpty {
            print("📤 Prepared \(temporaryFileURLs.count) file(s) for sharing")
        }

        return (temporaryFileURLs, temporaryFileURLs.isEmpty ? nil : shareDirectory)
    }

    private func findActualROMPath(romsBaseURL: URL, romName: String, fileManager: FileManager) -> URL? {
        guard let platformDirs = try? fileManager.contentsOfDirectory(
            at: romsBaseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for platformDir in platformDirs {
            let romDir = platformDir.appendingPathComponent(romName)
            if fileManager.fileExists(atPath: romDir.path) {
                return romDir
            }
        }

        return nil
    }

    private func cleanupTemporaryFiles() {
        guard let tempDir = temporaryShareDirectory else { return }

        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: tempDir)
            print("🗑️ Cleaned up temporary share directory")
        } catch {
            print("⚠️ Failed to cleanup temporary files: \(error)")
        }

        temporaryShareDirectory = nil
        shareSheetItem = nil
    }
}

/// Identifiable wrapper for share sheet URLs
private struct ShareSheetItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}
