import SwiftUI

@MainActor
final class BIOSSettingsViewModel: ObservableObject {
    @Published private(set) var sections: [Section] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    struct Section: Identifiable {
        let core: LibretroCore
        var statuses: [BIOSFileStatus]
        var id: String { core.rawValue }
    }

    private let useCase: PBIOSSyncUseCase
    private let cores: [LibretroCore] = [.pcsxRearmed]

    init(useCase: PBIOSSyncUseCase) {
        self.useCase = useCase
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        var newSections: [Section] = []
        for core in cores {
            do {
                let statuses = try await useCase.loadStatuses(for: core)
                newSections.append(Section(core: core, statuses: statuses))
            } catch {
                errorMessage = error.localizedDescription
                newSections.append(Section(core: core, statuses: []))
            }
        }
        sections = newSections
    }

    func download(_ status: BIOSFileStatus, in core: LibretroCore) async {
        do {
            try await useCase.download(status: status, into: useCase.systemDirectory())
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BIOSSettingsView: View {
    @StateObject private var viewModel: BIOSSettingsViewModel

    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        _viewModel = StateObject(wrappedValue: BIOSSettingsViewModel(useCase: factory.makeBIOSSyncUseCase()))
    }

    var body: some View {
        Form {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                ProgressView()
            }
            ForEach(viewModel.sections) { section in
                SwiftUI.Section(header: Text(section.core.displayName)) {
                    if section.statuses.isEmpty {
                        Text("Keine BIOS-Anforderungen konfiguriert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(section.statuses) { status in
                            BIOSRow(status: status) {
                                Task { await viewModel.download(status, in: section.core) }
                            }
                        }
                    }
                }
            }
            if let err = viewModel.errorMessage {
                SwiftUI.Section {
                    Text(err).foregroundStyle(.red)
                }
            }
            SwiftUI.Section(footer: footer) { EmptyView() }
        }
        .navigationTitle("BIOS Files")
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BIOS-Dateien werden vom ROMM-Server bezogen und unter Documents/LibretroSystem abgelegt.")
            Text("PCSX ReARMed startet bereits, wenn mindestens eine Regionalvariante (SCPH-5500/5501/5502) vorliegt.")
        }
        .font(.caption)
    }
}

private struct BIOSRow: View {
    let status: BIOSFileStatus
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.requirement.fileName)
                        .font(.system(.body, design: .monospaced))
                    if let note = status.requirement.note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !status.existsLocally && status.canDownload {
                    Button("Laden", action: onDownload)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            detailLine
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var statusIcon: some View {
        switch (status.existsLocally, status.localHashLooksValid, status.canDownload) {
        case (true, true, _):
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case (true, false, _):
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case (false, _, true):
            Image(systemName: "arrow.down.circle").foregroundStyle(.blue)
        case (false, _, false):
            Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var detailLine: some View {
        switch status.local {
        case .missing:
            switch status.server {
            case .available(_, let size, _, _):
                Text("Fehlt lokal · Server: \(formatBytes(size))").font(.caption2).foregroundStyle(.secondary)
            case .missing:
                Text("Fehlt lokal · Server hat diese Datei nicht.").font(.caption2).foregroundStyle(.secondary)
            case .unknown:
                Text("Fehlt lokal · Plattform nicht im ROMM-Server gefunden.").font(.caption2).foregroundStyle(.secondary)
            }
        case .present(let md5, let size):
            HStack(spacing: 8) {
                Text("Lokal \(formatBytes(size))")
                Text("MD5 \(md5.prefix(8))…")
                if status.localHashLooksValid {
                    Text("verifiziert").foregroundStyle(.green)
                } else {
                    Text("Hash unverified").foregroundStyle(.orange)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }
}
