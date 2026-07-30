import SwiftUI

struct AddEditSFTPDeviceView: View {
    @StateObject private var viewModel: AddEditSFTPDeviceViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (SFTPConnection, SFTPCredentials) -> Void
    
    init(connection: SFTPConnection? = nil, factory: PDependencyFactory = DefaultDependencyFactory.shared, onSave: @escaping (SFTPConnection, SFTPCredentials) -> Void) {
        self._viewModel = StateObject(wrappedValue: factory.makeAddEditSFTPDeviceViewModel(connection: connection))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                authenticationSection
                advancedSection
                testSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Device" : "Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDevice()
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section("Device Information") {
            TextField("Device Name", text: $viewModel.name)
                .textContentType(.name)
            
            TextField("Hostname or IP", text: $viewModel.host)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
            
            TextField("Username", text: $viewModel.username)
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
    
    private var authenticationSection: some View {
        Section("Authentication") {
            Picker("Authentication Type", selection: $viewModel.authenticationType) {
                ForEach(AuthenticationType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            
            switch viewModel.authenticationType {
            case .password:
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                
            case .sshKey:
                VStack(alignment: .leading) {
                    Text("Private Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $viewModel.privateKey)
                        .frame(minHeight: 100)
                        .font(.system(.caption, design: .monospaced))
                }
                
                SecureField("Passphrase (optional)", text: $viewModel.passphrase)
                    .textContentType(.password)
                
            case .passwordWithKey:
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                
                VStack(alignment: .leading) {
                    Text("Private Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $viewModel.privateKey)
                        .frame(minHeight: 100)
                        .font(.system(.caption, design: .monospaced))
                }
                
                SecureField("Passphrase (optional)", text: $viewModel.passphrase)
                    .textContentType(.password)
            }
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced Settings") {
            TextField("Root Path", text: $viewModel.rootPath)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            Toggle("Set as Default Device", isOn: $viewModel.isDefault)
        }
    }
    
    private var testSection: some View {
        Section("Connection Test") {
            HStack {
                Button("Test Connection") {
                    Task {
                        await viewModel.testConnection()
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isTestingConnection)
                
                Spacer()
                
                if viewModel.isTestingConnection {
                    LoadingView()
                        .frame(width: 20, height: 20)
                } else if let testResult = viewModel.testResult {
                    connectionTestResult(testResult)
                }
            }
        }
    }
    
    private func connectionTestResult(_ status: ConnectionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == .connected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(status == .connected ? "Success" : "Failed")
                .font(.caption)
                .foregroundColor(status == .connected ? .green : .red)
        }
    }
    
    private func saveDevice() {
        guard let result = viewModel.saveConnection() else { return }
        onSave(result.connection, result.credentials)
        dismiss()
    }
}

#Preview {
    AddEditSFTPDeviceView { _, _ in }
}