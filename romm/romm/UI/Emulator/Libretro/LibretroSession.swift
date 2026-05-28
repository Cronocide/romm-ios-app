import Foundation
import UIKit

@MainActor
final class LibretroSession: NSObject {

    private let gameURL: URL
    private let core: LibretroCore
    private let romId: Int
    private let saveStates: PEmulatorSaveStatesUseCase
    private let frontend = LibretroFrontend.shared

    var onMenuRequested: (() -> Void)?

    let viewController: LibretroGameViewController

    init(gameURL: URL, core: LibretroCore, romId: Int, saveStates: PEmulatorSaveStatesUseCase) {
        self.gameURL = gameURL
        self.core = core
        self.romId = romId
        self.saveStates = saveStates
        self.viewController = LibretroGameViewController(core: core, gameURL: gameURL)
        super.init()
        self.viewController.controllerView.onMenuTapped = { [weak self] in
            self?.onMenuRequested?()
        }
    }

    // MARK: - Lifecycle

    func start() {
        let videoView = viewController.videoView
        frontend.videoSink = videoView

        do {
            let corePath = try locateCoreDylib()
            let systemDir = libretroSystemDirectory().path
            let saveDir = libretroSaveDirectory().path
            print("[Libretro] core=\(corePath)")
            print("[Libretro] system=\(systemDir) save=\(saveDir)")
            try frontend.load(
                corePath: corePath,
                gamePath: gameURL.path,
                systemDir: systemDir,
                saveDir: saveDir
            )
            frontend.startRunLoop()
        } catch {
            print("[Libretro] start failed: \(error.localizedDescription)")
            viewController.showError(error.localizedDescription)
        }
    }

    func pause() { frontend.pause() }
    func resume() { frontend.resume() }

    func stop() {
        frontend.stop()
        frontend.videoSink = nil
    }

    // MARK: - Save state API (mirrors DeltaCoreSession)

    func hasState(slot: Int) -> Bool {
        (try? saveStates.readState(romId: romId, slot: slot)) != nil
    }

    func stateModifiedAt(slot: Int) -> Date? {
        saveStates.stateModifiedAt(romId: romId, slot: slot)
    }

    func thumbnail(slot: Int) -> UIImage? {
        guard let data = try? saveStates.readThumbnail(romId: romId, slot: slot) else { return nil }
        return UIImage(data: data)
    }

    func hasUndoSave(slot: Int) -> Bool { saveStates.hasUndoSave(romId: romId, slot: slot) }
    func hasUndoLoad() -> Bool { saveStates.hasUndoLoad(romId: romId) }

    func saveState(slot: Int) throws {
        guard let data = frontend.saveStateData() else {
            throw LibretroFrontend.FrontendError.symbolMissing("retro_serialize")
        }
        try saveStates.backupSlotForUndoSave(romId: romId, slot: slot)
        try saveStates.writeState(romId: romId, slot: slot, data: data)
        if let thumb = viewController.videoView.snapshot()?.pngData() {
            try saveStates.writeThumbnail(romId: romId, slot: slot, data: thumb)
        }
    }

    func loadState(slot: Int) throws {
        guard let data = try saveStates.readState(romId: romId, slot: slot) else { return }
        if let snapshot = frontend.saveStateData() {
            let thumb = viewController.videoView.snapshot()?.pngData()
            try saveStates.writeUndoLoadSnapshot(romId: romId, stateData: snapshot, thumbnailData: thumb)
        }
        guard frontend.loadStateData(data) else {
            throw LibretroFrontend.FrontendError.symbolMissing("retro_unserialize")
        }
    }

    func undoSave(slot: Int) throws {
        _ = try saveStates.restoreSlotFromUndoSave(romId: romId, slot: slot)
    }

    func undoLoad() throws {
        guard let data = try saveStates.readUndoLoadState(romId: romId) else { return }
        guard frontend.loadStateData(data) else {
            throw LibretroFrontend.FrontendError.symbolMissing("retro_unserialize")
        }
        try saveStates.clearUndoLoad(romId: romId)
    }

    // MARK: - Paths

    /// Dylib-Lookup. Konvention:
    ///   1. App-Bundle: `Frameworks/<dylibName>.framework/<dylibName>`
    ///   2. App-Bundle: `Frameworks/<dylibName>.dylib`
    ///   3. Documents/LibretroCores/<dylibName>.dylib  (manueller Sideload via Files-App)
    private func locateCoreDylib() throws -> String {
        let name = core.dylibName

        if let url = Bundle.main.privateFrameworksURL?
            .appendingPathComponent("\(name).framework", isDirectory: true)
            .appendingPathComponent(name),
           FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        if let url = Bundle.main.privateFrameworksURL?
            .appendingPathComponent("\(name).dylib"),
           FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }

        let docCandidate = documentsDirectory()
            .appendingPathComponent("LibretroCores", isDirectory: true)
            .appendingPathComponent("\(name).dylib")
        if FileManager.default.fileExists(atPath: docCandidate.path) {
            return docCandidate.path
        }
        throw LibretroFrontend.FrontendError.dylibNotFound(name)
    }

    private func libretroSystemDirectory() -> URL {
        documentsDirectory().appendingPathComponent("LibretroSystem", isDirectory: true)
    }

    private func libretroSaveDirectory() -> URL {
        documentsDirectory().appendingPathComponent("LibretroSaves", isDirectory: true)
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

final class LibretroGameViewController: UIViewController {
    private let core: LibretroCore
    private let gameURL: URL
    let videoView = LibretroVideoView()
    let controllerView = LibretroTouchControllerView()
    private let errorLabel = UILabel()

    init(core: LibretroCore, gameURL: URL) {
        self.core = core
        self.gameURL = gameURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        videoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoView)
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        controllerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controllerView)
        NSLayoutConstraint.activate([
            controllerView.topAnchor.constraint(equalTo: view.topAnchor),
            controllerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controllerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controllerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        errorLabel.numberOfLines = 0
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 14, weight: .medium)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.controllerView.setNeedsLayout()
            self?.controllerView.layoutIfNeeded()
        })
    }
}
