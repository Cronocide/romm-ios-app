import SwiftUI

struct TransferHistoryView: View {
    @State private var viewModel: TransferHistoryViewModel

    init(deviceId: UUID, factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self._viewModel = State(wrappedValue: TransferHistoryViewModel(
            deviceId: deviceId,
            factory: factory
        ))
    }

    var body: some View {
        Group {
            if viewModel.hasHistory {
                historyList
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Transfer History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.hasHistory {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        viewModel.confirmClearHistory()
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadHistory()
        }
        .alert("Clear History?", isPresented: $viewModel.showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This will permanently delete all transfer history for this device.")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Transfer History")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Transfers to this device will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var historyList: some View {
        List {
            Section {
                summaryCard
            }

            ForEach(viewModel.platformGroups) { platformGroup in
                Section(platformGroup.platformName) {
                    ForEach(platformGroup.transfers) { transfer in
                        TransferHistoryRow(transfer: transfer)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Transfers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(viewModel.totalTransfers)")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.totalSizeFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            Text("\(viewModel.platformGroups.count) platforms")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TransferHistoryRow: View {
    let transfer: TransferHistory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Transfer type icon
            Image(systemName: transferIcon)
                .font(.title3)
                .foregroundColor(transfer.success ? .blue : .red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(transfer.romName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(transfer.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(transfer.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !transfer.success {
                    Text("Failed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var transferIcon: String {
        switch transfer.transferType {
        case .upload:
            return "arrow.up.circle.fill"
        case .download:
            return "arrow.down.circle.fill"
        }
    }
}

#Preview {
    NavigationStack {
        TransferHistoryView(deviceId: UUID())
    }
}
