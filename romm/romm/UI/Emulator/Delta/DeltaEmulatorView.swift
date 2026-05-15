import SwiftUI
import DeltaCore

struct DeltaEmulatorView: View {
    @SwiftUI.State private var viewModel: DeltaEmulatorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(rom: Rom, gameType: DeltaGameType, factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self._viewModel = SwiftUI.State(wrappedValue: DeltaEmulatorViewModel(
            rom: rom, gameType: gameType,
            localROMRepo: factory.localROMRepository
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = viewModel.session {
                DeltaGameViewControllerHost(controller: session.viewController)
                    .ignoresSafeArea()
            }
            if let error = viewModel.errorMessage {
                ErrorOverlay(message: error) { dismiss() }
            }
        }
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

private struct DeltaGameViewControllerHost: UIViewControllerRepresentable {
    let controller: GameViewController
    func makeUIViewController(context: Context) -> GameViewController { controller }
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

private struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundColor(.red)
            Text(message).foregroundColor(.white).multilineTextAlignment(.center)
            Button("Close", action: onDismiss).foregroundColor(.white)
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.9)))
        .padding()
    }
}
