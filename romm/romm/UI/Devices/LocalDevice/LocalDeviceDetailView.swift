import SwiftUI

struct LocalDeviceDetailView: View {
    @State private var viewModel = LocalDeviceDetailViewModel()

    private var device: LocalDevice {
        LocalDeviceManager.shared.currentDevice
    }

    var body: some View {
        Group {
            if viewModel.hasDownloadedROMs {
                downloadedROMsList
            } else {
                emptyStateView
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load data on first appear
            await viewModel.loadDownloadedROMsAsync()
        }
        .refreshable {
            await viewModel.loadDownloadedROMsAsync()
            await viewModel.refreshStorageInfo()
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
            Image(systemName: "iphone")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Downloaded ROMs")
                .font(.title2)
                .fontWeight(.semibold)

            Text("ROMs downloaded to this device will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            storageInfoCard
                .padding(.top, 20)
        }
        .padding()
    }

    private var downloadedROMsList: some View {
        List {
            Section {
                storageInfoCard
            }

            Section("Platforms") {
                ForEach(viewModel.platformNames, id: \.self) { platformName in
                    if let roms = viewModel.romsByPlatform[platformName] {
                        NavigationLink {
                            PlatformROMsListView(
                                platformName: platformName,
                                roms: roms,
                                onDelete: { rom in
                                    viewModel.deleteROM(rom)
                                }
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(platformName)
                                        .font(.headline)

                                    Text("\(roms.count) ROM\(roms.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Total size for this platform
                                let totalSize = roms.reduce(0) { $0 + $1.totalSizeBytes }
                                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var storageInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(device.availableStorageFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(device.hasLowStorage ? .orange : .primary)

                    Text("available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Downloaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.totalDownloadedSizeFormatted)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(viewModel.downloadedROMs.count) ROMs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Storage usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Usage
                    RoundedRectangle(cornerRadius: 4)
                        .fill(device.hasLowStorage ? Color.orange : Color.blue)
                        .frame(
                            width: geometry.size.width * CGFloat(device.storageUsagePercentage / 100),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(device.storageUsagePercentage))% used")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(device.totalStorageFormatted + " total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        LocalDeviceDetailView()
    }
}
