import SwiftUI
import DeltaCore

struct DeltaEmulatorView: View {
    @SwiftUI.State private var viewModel: DeltaEmulatorViewModel
    @SwiftUI.State private var showMenu = false
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
        .onAppear {
            viewModel.bootstrap()
            viewModel.session?.onMenuRequested = { showMenu = true }
        }
        .onDisappear { viewModel.teardown() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.session?.resume()
            case .inactive, .background: viewModel.session?.pause()
            @unknown default: break
            }
        }
        .onChange(of: showMenu) { _, presented in
            if presented {
                viewModel.session?.pause()
            } else {
                viewModel.session?.resume()
            }
        }
        .sheet(isPresented: $showMenu) {
            EmulatorMenuSheet(
                session: viewModel.session,
                onResume: { showMenu = false },
                onQuit: {
                    showMenu = false
                    dismiss()
                }
            )
            .presentationDetents([.medium])
        }
    }
}

private struct EmulatorMenuSheet: View {
    let session: DeltaCoreSession?
    let onResume: () -> Void
    let onQuit: () -> Void

    @SwiftUI.State private var statusMessage: String?

    private let slots = [1, 2, 3]

    var body: some View {
        NavigationStack {
            List {
                Section("Save State") {
                    ForEach(slots, id: \.self) { slot in
                        Button {
                            do {
                                try session?.saveState(slot: slot)
                                statusMessage = "Slot \(slot) gespeichert"
                            } catch {
                                statusMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
                            }
                        } label: {
                            Label("Slot \(slot) speichern", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
                Section("Load State") {
                    ForEach(slots, id: \.self) { slot in
                        let exists = session?.hasState(slot: slot) ?? false
                        Button {
                            do {
                                try session?.loadState(slot: slot)
                                onResume()
                            } catch {
                                statusMessage = "Laden fehlgeschlagen: \(error.localizedDescription)"
                            }
                        } label: {
                            Label("Slot \(slot) laden", systemImage: "tray.and.arrow.up")
                                .foregroundColor(exists ? .primary : .secondary)
                        }
                        .disabled(!exists)
                    }
                }
                if let statusMessage {
                    Section { Text(statusMessage).font(.footnote) }
                }
                Section {
                    Button("Fortsetzen", action: onResume)
                    Button("Spiel beenden", role: .destructive, action: onQuit)
                }
            }
            .navigationTitle("Menü")
            .navigationBarTitleDisplayMode(.inline)
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
