import Foundation
import UIKit

@MainActor
final class LibretroSession: NSObject {

    private let gameURL: URL
    private let core: LibretroCore
    private let romId: Int
    private let saveStore: PSaveStore
    private let frontend = LibretroFrontend.shared

    var onMenuRequested: (() -> Void)?

    let viewController: LibretroGameViewController

    init(gameURL: URL, core: LibretroCore, romId: Int, saveStore: PSaveStore) {
        self.gameURL = gameURL
        self.core = core
        self.romId = romId
        self.saveStore = saveStore
        self.viewController = LibretroGameViewController(core: core, gameURL: gameURL)
        super.init()
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

    func pause() { /* TODO: timer pause */ }
    func resume() { /* TODO: timer resume */ }

    func stop() {
        frontend.stop()
        frontend.videoSink = nil
    }

    func hasState(slot: Int) -> Bool {
        (try? saveStore.readState(romId: romId, slot: slot)) != nil
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
}
