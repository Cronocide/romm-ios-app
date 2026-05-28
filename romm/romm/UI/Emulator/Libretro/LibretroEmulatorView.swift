import SwiftUI
import UIKit

struct LibretroEmulatorView: View {
    @SwiftUI.State private var viewModel: LibretroEmulatorViewModel
    @SwiftUI.State private var showMenu = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(rom: Rom, core: LibretroCore, factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self._viewModel = SwiftUI.State(wrappedValue: factory.makeLibretroEmulatorViewModel(rom: rom, core: core))
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
        .onAppear {
            OrientationLock.set([.portrait, .landscapeLeft, .landscapeRight])
            viewModel.onMenuRequested = { showMenu = true }
            viewModel.bootstrap()
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
            LibretroMenuSheet(
                session: viewModel.session,
                onResume: { showMenu = false },
                onQuit: {
                    showMenu = false
                    dismiss()
                }
            )
            .preferredColorScheme(.dark)
        }
    }
}

private struct LibretroMenuSheet: View {
    let session: LibretroSession?
    let onResume: () -> Void
    let onQuit: () -> Void

    @SwiftUI.State private var selectedSlot: Int = 1
    @SwiftUI.State private var statusMessage: String?
    @SwiftUI.State private var refreshTick: Int = 0
    @SwiftUI.State private var showQuitConfirmation = false

    private let slots = Array(1...20)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    detailHeader
                    actionButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    Divider().background(Color.white.opacity(0.1))
                    slotList
                }
            }
            .navigationTitle("Save States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quit", role: .destructive) {
                        showQuitConfirmation = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onResume).bold()
                }
            }
            .alert(
                "Quit Game?",
                isPresented: $showQuitConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Quit", role: .destructive, action: onQuit)
            } message: {
                Text("Unsaved progress will be lost.")
            }
        }
    }

    private var detailHeader: some View {
        VStack(spacing: 10) {
            previewArea
            HStack(spacing: 8) {
                Text("Slot \(selectedSlot)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let date = session?.stateModifiedAt(slot: selectedSlot) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Empty")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .id(refreshTick)
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
            if let image = session?.thumbnail(slot: selectedSlot) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("No save state")
                        .font(.footnote)
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(height: 180)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var slotList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(slots, id: \.self) { slot in
                    slotRow(slot)
                    if slot != slots.last {
                        Divider().background(Color.white.opacity(0.06))
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private func slotRow(_ slot: Int) -> some View {
        let isSelected = slot == selectedSlot
        let occupied = session?.hasState(slot: slot) == true
        Button {
            selectedSlot = slot
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                Text("Slot \(slot)")
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
                if occupied {
                    Circle().fill(.green).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            stackedButton(
                title: "Load",
                icon: "tray.and.arrow.up",
                tint: .accentColor,
                filled: true,
                disabled: session?.hasState(slot: selectedSlot) != true
            ) {
                perform { try session?.loadState(slot: selectedSlot) }
                statusMessage = "Slot \(selectedSlot) loaded"
                onResume()
            }
            stackedButton(
                title: "Save",
                icon: "tray.and.arrow.down",
                tint: .accentColor,
                filled: false,
                disabled: false
            ) {
                perform { try session?.saveState(slot: selectedSlot) }
                statusMessage = "Slot \(selectedSlot) saved"
                refreshTick += 1
            }
            stackedButton(
                title: "Undo Save",
                icon: "arrow.uturn.backward",
                tint: .orange,
                filled: false,
                disabled: session?.hasUndoSave(slot: selectedSlot) != true
            ) {
                perform { try session?.undoSave(slot: selectedSlot) }
                statusMessage = "Save for slot \(selectedSlot) undone"
                refreshTick += 1
            }
            stackedButton(
                title: "Undo Load",
                icon: "arrow.uturn.backward.circle",
                tint: .orange,
                filled: false,
                disabled: session?.hasUndoLoad() != true
            ) {
                perform { try session?.undoLoad() }
                statusMessage = "Load undone"
                onResume()
            }
        }
    }

    @ViewBuilder
    private func stackedButton(
        title: String,
        icon: String,
        tint: Color,
        filled: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(filled ? .black : tint)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(filled ? tint : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(filled ? Color.clear : tint.opacity(0.4), lineWidth: 1)
            )
            .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}

private struct LibretroHostView: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
