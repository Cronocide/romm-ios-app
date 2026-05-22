import SwiftUI
import UIKit

struct LibretroEmulatorView: View {
    @SwiftUI.State private var viewModel: LibretroEmulatorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(rom: Rom, core: LibretroCore, factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self._viewModel = SwiftUI.State(wrappedValue: LibretroEmulatorViewModel(
            rom: rom, core: core,
            localROMRepo: factory.localROMRepository
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = viewModel.session, !viewModel.isLoading {
                LibretroHostView(viewController: session.viewController)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if viewModel.isLoading {
                ProgressView("Lade \(viewModel.rom.name) …")
                    .foregroundStyle(.white)
            }
            if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("Libretro Fehler").font(.headline).foregroundStyle(.white)
                    Text(error).font(.caption).foregroundStyle(.white.opacity(0.7))
                    Button("Schließen") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.isLoading)
        .onAppear { viewModel.bootstrap() }
        .onDisappear { viewModel.teardown() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.session?.resume()
            case .inactive, .background: viewModel.session?.pause()
            @unknown default: break
            }
        }
    }
}

private struct LibretroHostView: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
