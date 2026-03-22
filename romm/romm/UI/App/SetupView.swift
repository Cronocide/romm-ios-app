//
//  SetupView.swift
//  romm
//
//  Created by Ilyas Hallak on 07.08.25.
//

import SwiftUI

struct SetupView: View {
    let appViewModel: AppViewModel
    @State private var serverURL = "https://romm​.spinnich​.net"
    @State private var username = ""
    @State private var password = ""
    @State private var showConnectionDetails = false

    // Connection validation states
    @State private var isConnecting = false
    @State private var serverValidated = false
    @State private var detectedServerVersion: String?
    @State private var connectionError: String?
    @State private var connectionErrorDetails: String?
    @State private var isErrorExpanded = false
    @State private var isVersionWarning = false  // true if error is just a warning (incompatible but can proceed)
    @State private var didAcceptIncompatibleVersion = false
    
    // OIDC states
    @State private var detectedAuthCapability: HeartbeatRepository.AuthCapabilities?
    @State private var selectedAuthMethod: AuthMethod = .classic
    @State private var isPerformingOIDC = false
    @State private var oidcConfiguration: OIDCConfiguration?
    @State private var oidcError: String?

    // Client Token states
    @State private var clientTokenInput = ""
    @State private var isExchangingToken = false
    @State private var clientTokenError: String?
    @State private var showQRScanner = false

    private var connectionLogger: ConnectionLogger { ConnectionLogger.shared }
    private let launchArguments = ProcessInfo.processInfo.arguments
    private var shouldShowLoginForUITests: Bool { launchArguments.contains("-ui_testing_show_login") }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image("romm_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)

                        Text("RomM Setup")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Configure your ROM Management System")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Setup Form
                    VStack(spacing: 20) {
                        // MARK: - Step 1: Server URL
                        serverURLSection

                        // MARK: - Step 2: Login (only shown after server validation)
                        if serverValidated {
                            loginSection
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                    }
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.3), value: serverValidated)

                    // Error Message from AppViewModel
                    if let errorMessage = appViewModel.appData.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Login Button (only when server validated)
                    if serverValidated {
                        loginButton
                            .transition(.opacity)
                    }

                    // Info Text
                    if serverValidated {
                        VStack(spacing: 8) {
                            Text("Your credentials will be stored securely")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Password will not be stored locally")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    }

                    // Connection Debug Panel
                    if !connectionLogger.logs.isEmpty || connectionLogger.isConnecting {
                        ConnectionDebugPanel(
                            logs: connectionLogger.logs,
                            isExpanded: $showConnectionDetails
                        )
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                seedUITestLoginStateIfNeeded()
            }
            .onTapGesture {
                hideKeyboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clientTokenPairingCode)) { notification in
                if let code = notification.userInfo?["code"] as? String {
                    Task {
                        await performClientTokenPairing(code: code)
                    }
                }
            }
        }
    }

    // MARK: - Server URL Section

    private var serverURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Server URL")
                    .font(.headline)

                Spacer()

                // Status indicator
                if serverValidated {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        if let version = detectedServerVersion {
                            Text("v\(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("",
                          text: $serverURL,
                          prompt: Text(verbatim: "https://romm.example.com")
                    .foregroundColor(.secondary))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(serverValidated)
                    .opacity(serverValidated ? 0.7 : 1.0)
                    .onChange(of: serverURL) { _, _ in
                        // Reset validation when URL changes
                        if serverValidated {
                            resetServerValidation()
                        }
                    }

                // Connect/Change button
                Button {
                    if serverValidated {
                        resetServerValidation()
                    } else {
                        Task {
                            await validateServer()
                        }
                    }
                } label: {
                    if isConnecting {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else if serverValidated {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body.weight(.medium))
                    } else {
                        Text("Connect")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverURL.isEmpty || isConnecting)
            }

            // Quick input chips
            if !serverValidated {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickInputChip(text: "192.168.", action: { insertText("192.168.") })
                        QuickInputChip(text: "http://", action: { insertText("http://") })
                        QuickInputChip(text: "https://", action: { insertText("https://") })
                        QuickInputChip(text: ":8080", action: { insertText(":8080") })
                        QuickInputChip(text: ".com", action: { insertText(".com") })
                        QuickInputChip(text: ".de", action: { insertText(".de") })
                    }
                }
            }

            // Connection error/warning message
            if let error = connectionError {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isErrorExpanded.toggle()
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: isVersionWarning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                                .foregroundColor(isVersionWarning ? .orange : .red)
                                .font(.caption)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(isVersionWarning ? .orange : .red)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if connectionErrorDetails != nil {
                                Image(systemName: isErrorExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Expandable details
                    if isErrorExpanded, let details = connectionErrorDetails {
                        Text(details)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Show "Continue anyway" button for version warnings
                    if isVersionWarning, detectedServerVersion != nil {
                        Button("Continue anyway") {
                            serverValidated = true
                            connectionError = nil
                            connectionErrorDetails = nil
                            isVersionWarning = false
                            isErrorExpanded = false
                            didAcceptIncompatibleVersion = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.orange)
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }

            if !serverValidated && connectionError == nil {
                Text(verbatim: "e.g. http://192.168.1.100 or https://romm.example.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Login Section

    private var loginSection: some View {
        VStack(spacing: 16) {
            // Auth Method Selection (if server supports multiple methods)
            if let capability = detectedAuthCapability {
                let methods = AuthMethod.availableMethods(for: capability)
                if methods.count > 1 {
                    authMethodPicker
                }
            }
            
            // Classic Auth Fields (Username/Password)
            if selectedAuthMethod == .classic {
                classicAuthFields
            }
            
            // OIDC Info (if OIDC selected)
            if selectedAuthMethod == .oidc {
                oidcAuthInfo
            }

            // Client Token Auth (if client token selected)
            if selectedAuthMethod == .clientToken {
                clientTokenAuthSection
            }

            // OIDC Error
            if let oidcError = oidcError {
                Text(oidcError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Auth Method Picker
    
    private var authMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Authentication Method")
                .font(.headline)
            
            Picker("Auth Method", selection: $selectedAuthMethod) {
                ForEach(AuthMethod.allCases, id: \.self) { method in
                    Label(method.displayName, systemImage: method.iconName)
                        .tag(method)
                }
            }
            .pickerStyle(.segmented)
            
            Text(selectedAuthMethod.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Classic Auth Fields
    
    private var classicAuthFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.headline)
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocapitalization(.none)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.headline)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
        }
    }
    
    // MARK: - OIDC Auth Info
    
    private var oidcAuthInfo: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browser Authentication")
                        .font(.headline)
                    Text("You'll be redirected to your browser to sign in securely")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Client Token Auth Section

    private var clientTokenAuthSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Token")
                        .font(.headline)
                    Text("Connect using a token from your RomM server settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button {
                showQRScanner = true
            } label: {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR Code")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                Text("or").font(.caption).foregroundColor(.secondary)
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste Token")
                    .font(.headline)
                TextField("rmm_...", text: $clientTokenInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
            }

            if let error = clientTokenError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { code in
                showQRScanner = false
                Task {
                    await performClientTokenPairing(code: code)
                }
            }
        }
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button {
            Task {
                if selectedAuthMethod == .oidc {
                    await performOIDCLogin()
                } else if selectedAuthMethod == .clientToken {
                    await performClientTokenLogin()
                } else {
                    await performClassicLogin()
                }
            }
        } label: {
            if appViewModel.appData.isLoading || isPerformingOIDC || isExchangingToken {
                HStack {
                    ProgressView()
                        .frame(width: 20, height: 20)
                    Text(isPerformingOIDC ? "Opening browser..." : isExchangingToken ? "Connecting..." : "Logging in...")
                }
            } else {
                HStack {
                    Image(systemName: selectedAuthMethod.iconName)
                    Text(selectedAuthMethod == .oidc ? "Login with Browser" : selectedAuthMethod == .clientToken ? "Connect with Token" : "Login")
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canProceedWithLogin)
        .padding(.horizontal, 24)
    }
    
    private var canProceedWithLogin: Bool {
        if appViewModel.appData.isLoading || isPerformingOIDC || isExchangingToken {
            return false
        }
        switch selectedAuthMethod {
        case .classic:
            return !username.isEmpty && !password.isEmpty
        case .oidc:
            return oidcConfiguration != nil
        case .clientToken:
            return !clientTokenInput.isEmpty
        }
    }

    // MARK: - Actions

    private func validateServer() async {
        hideKeyboard()
        isConnecting = true
        connectionError = nil
        connectionErrorDetails = nil
        isErrorExpanded = false
        isVersionWarning = false
        didAcceptIncompatibleVersion = false
        detectedAuthCapability = nil
        oidcConfiguration = nil
        oidcError = nil

        do {
            let version = try await appViewModel.fetchServerVersion(from: serverURL)
            detectedServerVersion = version

            if appViewModel.isVersionCompatible(version) {
                // Compatible - proceed with auth detection
                serverValidated = true
                connectionError = nil
                didAcceptIncompatibleVersion = false
                
                // Detect authentication capabilities
                await detectAuthenticationMethod()
            } else {
                // Incompatible - show warning but allow to proceed
                connectionError = "Server version \(version) is not compatible"
                connectionErrorDetails = "Supported range: \(appViewModel.minSupportedServerVersion) - \(appViewModel.maxSupportedServerVersion). Some features may not work correctly."
                isVersionWarning = true
            }
        } catch let error as APIClientError {
            // Handle Cloudflare protection specifically
            if case .cloudflareProtection = error {
                // Mark server as validated - OIDC can still work
                serverValidated = true
                
                // Set a placeholder version for Cloudflare-protected servers
                detectedServerVersion = "Cloudflare"
                
                // Show info but not as blocking error
                connectionError = nil // Clear error so login section shows
                connectionErrorDetails = nil
                isVersionWarning = false
                isErrorExpanded = false
                
                Logger.oidc.warning("🔒 Cloudflare detected, proceeding with OIDC detection...")
                
                // Cloudflare detected - try OIDC discovery anyway
                await detectAuthenticationMethod()
            } else {
                // Parse other API errors
                let (message, details) = parseConnectionError(error)
                connectionError = message
                connectionErrorDetails = details
                isVersionWarning = false
            }
            didAcceptIncompatibleVersion = false
        } catch {
            // Parse general error for user-friendly message
            let (message, details) = parseConnectionError(error)
            connectionError = message
            connectionErrorDetails = details
            isVersionWarning = false
            didAcceptIncompatibleVersion = false
        }

        isConnecting = false
    }
    
    // MARK: - Auth Detection
    
    private func detectAuthenticationMethod() async {
        let heartbeatRepo = HeartbeatRepository()
        Logger.oidc.info("Detecting authentication methods...")
        let capabilities = await heartbeatRepo.detectAuthCapabilities(serverURL: serverURL)
        detectedAuthCapability = capabilities
        Logger.oidc.info("Detected capabilities: \(capabilities.description)")
        connectionError = nil
        connectionErrorDetails = nil

        if capabilities.unreachable {
            serverValidated = false
            connectionError = "Server is unreachable"
            connectionErrorDetails = "Could not connect to the server."
            return
        }
        if capabilities.cloudflareBlocked {
            Logger.oidc.warning("Cloudflare detected, trying OIDC with default config")
            selectedAuthMethod = .oidc
            serverValidated = true
            await discoverOIDCConfiguration()
            return
        }
        serverValidated = true
        if capabilities.oidc {
            selectedAuthMethod = .oidc
            await discoverOIDCConfiguration()
        } else if capabilities.classic {
            selectedAuthMethod = .classic
        } else if capabilities.clientTokens {
            selectedAuthMethod = .clientToken
        }
    }
    
    private func discoverOIDCConfiguration() async {
        Logger.oidc.info("🔍 Discovering OIDC configuration...")
        
        let oidcService = OIDCAuthService()
        
        do {
            let config = try await oidcService.discoverConfiguration(serverURL: serverURL)
            oidcConfiguration = config
            Logger.oidc.info("✅ OIDC configuration discovered")
        } catch {
            Logger.oidc.error("❌ OIDC discovery failed: \(error)")
            
            // Fallback: Use default OIDC configuration
            // This is common for servers behind Cloudflare where .well-known is also protected
            Logger.oidc.warning("⚠️ Using default OIDC configuration as fallback")
            
            let fallbackConfig = OIDCConfiguration.default(for: serverURL)
            oidcConfiguration = fallbackConfig
            
            Logger.oidc.info("✅ Using default OIDC configuration")
            Logger.oidc.debug("Config: \(fallbackConfig.description)")
            
            // Show info to user
            oidcError = nil // Clear any error - fallback is OK
        }
    }

    private func parseConnectionError(_ error: Error) -> (message: String, details: String?) {
        // Handle APIClientError specifically
        if let apiError = error as? APIClientError {
            switch apiError {
            case .cloudflareProtection:
                return ("🔒 Cloudflare protection detected", "This server requires browser-based authentication (OIDC/SSO)")
            case .oidcRequired:
                return ("OIDC authentication required", "This server only supports browser-based login")
            case .authenticationRequired:
                return ("Authentication failed", "Invalid username or password")
            case .invalidURL(let url):
                return ("Invalid URL", "The URL '\(url)' is not valid")
            case .noConfiguration:
                return ("Configuration error", "Server configuration is missing")
            case .noCredentials:
                return ("Credentials missing", "Please provide username and password")
            case .invalidResponse(let code, _):
                return ("Server error (\(code))", "The server returned an error response")
            case .decodingError:
                return ("Invalid response", "The server did not return a valid RomM response")
            case .networkError(let underlyingError):
                // Fall through to general error parsing
                return parseGeneralConnectionError(underlyingError)
            }
        }

        return parseGeneralConnectionError(error)
    }

    private func parseGeneralConnectionError(_ error: Error) -> (message: String, details: String?) {
        let errorString = error.localizedDescription

        // Certificate errors
        if errorString.contains("certificate") || errorString.contains("SSL") || errorString.contains("TLS") {
            return ("SSL/TLS certificate error", "Check if the server has a valid certificate or use http:// instead of https://")
        }

        // Connection refused
        if errorString.contains("Could not connect") || errorString.contains("Connection refused") {
            return ("Connection failed", "Check if the server is running and the URL is correct.")
        }

        // Timeout
        if errorString.contains("timed out") || errorString.contains("timeout") {
            return ("Connection timed out", "The server did not respond in time. Check if the server is reachable.")
        }

        // Host not found
        if errorString.contains("host") || errorString.contains("DNS") || errorString.contains("resolve") {
            return ("Server not found", "DNS resolution failed. Check the server URL.")
        }

        // Network unreachable
        if errorString.contains("network") || errorString.contains("internet") {
            return ("Network error", "Check your internet connection.")
        }

        // Invalid response (not a RomM server)
        if errorString.contains("decode") || errorString.contains("JSON") || errorString.contains("invalid") {
            return ("Invalid response", "The server did not return a valid RomM response. Is this a RomM server?")
        }

        // Generic error
        return ("Connection error", errorString)
    }

    private func resetServerValidation() {
        serverValidated = false
        detectedServerVersion = nil
        connectionError = nil
        connectionErrorDetails = nil
        isErrorExpanded = false
        isVersionWarning = false
        didAcceptIncompatibleVersion = false
        username = ""
        password = ""
    }

    private func performClassicLogin() async {
        // Store the server version for foreground checks
        if let version = detectedServerVersion {
            appViewModel.saveServerVersion(version)
        }
        await appViewModel.saveConfiguration(
            serverURL: serverURL,
            username: username,
            password: password
        )
    }
    
    private func performOIDCLogin() async {
        Logger.oidc.info("🚀 Starting OIDC login flow...")
        
        guard let config = oidcConfiguration else {
            Logger.oidc.error("❌ No OIDC configuration available")
            oidcError = "OIDC is not configured. Please try again."
            return
        }
        
        isPerformingOIDC = true
        oidcError = nil
        
        // Get the window for presentation context
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            Logger.oidc.error("❌ Cannot get window for authentication session")
            oidcError = "Cannot open browser for authentication"
            isPerformingOIDC = false
            return
        }
        
        let oidcService = OIDCAuthService()
        
        do {
            // Step 1: Authorize (opens browser)
            Logger.oidc.info("📱 Opening browser for authorization...")
            let (code, _) = try await oidcService.authorize(
                configuration: config,
                presentationContext: window
            )
            
            Logger.oidc.info("✅ Authorization successful, exchanging code for tokens...")
            
            // Step 2: Exchange code for tokens
            let tokens = try await oidcService.exchangeCodeForTokens(
                code: code,
                configuration: config
            )
            
            Logger.oidc.info("✅ Tokens received!")
            Logger.oidc.debug("Access token expires: \(tokens.expirationDescription)")
            
            // Step 3: Save configuration and tokens
            let setupRepo = SetupRepository()
            try setupRepo.saveOIDCConfiguration(config)
            try setupRepo.saveOIDCTokens(tokens)
            try setupRepo.saveAuthMethod(.oidc)
            
            // Step 4: Extract username from ID token if available
            let username = tokens.username ?? tokens.email ?? "OIDC User"
            
            // Step 5: Save server version
            if let version = detectedServerVersion {
                appViewModel.saveServerVersion(version)
            }
            
            // Step 6: Create minimal setup configuration for compatibility
            let setupConfig = SetupConfiguration(
                serverURL: serverURL,
                username: username,
                password: nil, // No password for OIDC
                token: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                setupDate: Date(),
                version: detectedServerVersion ?? "unknown",
                allowIncompatibleVersionLogin: didAcceptIncompatibleVersion
            )
            
            try setupRepo.saveSetupConfiguration(setupConfig)
            
            Logger.oidc.info("✅ OIDC login complete!")
            
            // Trigger app refresh by clearing loading state
            Task { @MainActor in
                appViewModel.appData.isLoading = false
                appViewModel.appData.errorMessage = nil
            }
            
            isPerformingOIDC = false
            
        } catch let error as OIDCError {
            Logger.oidc.error("❌ OIDC error: \(error.detailedMessage)")
            oidcError = error.userMessage
            isPerformingOIDC = false
        } catch {
            Logger.oidc.error("❌ Unexpected error: \(error)")
            oidcError = "Authentication failed: \(error.localizedDescription)"
            isPerformingOIDC = false
        }
    }

    // MARK: - Client Token Login

    @MainActor
    private func performClientTokenLogin() async {
        isExchangingToken = true
        clientTokenError = nil
        let service = ClientTokenAuthService()
        do {
            let tokenInfo = try await service.validateToken(serverURL: serverURL, token: clientTokenInput)
            try service.saveToken(clientTokenInput, info: tokenInfo)
            let setupRepo = SetupRepository()
            if let version = detectedServerVersion {
                appViewModel.saveServerVersion(version)
            }
            try setupRepo.saveClientTokenSetup(
                serverURL: serverURL,
                tokenName: tokenInfo.name,
                version: detectedServerVersion ?? "unknown",
                allowIncompatibleVersionLogin: didAcceptIncompatibleVersion
            )
            Logger.auth.info("Client token login complete")
            appViewModel.appData.isLoading = false
            appViewModel.appData.errorMessage = nil
            // Trigger app state transition to authenticated
            await appViewModel.checkInitialState()
        } catch {
            Logger.auth.error("Client token login failed: \(error)")
            clientTokenError = error.localizedDescription
        }
        isExchangingToken = false
    }

    @MainActor
    private func performClientTokenPairing(code: String) async {
        isExchangingToken = true
        clientTokenError = nil
        let service = ClientTokenAuthService()
        do {
            let (token, tokenInfo) = try await service.exchangeCode(serverURL: serverURL, code: code)
            try service.saveToken(token, info: tokenInfo)
            let setupRepo = SetupRepository()
            if let version = detectedServerVersion {
                appViewModel.saveServerVersion(version)
            }
            try setupRepo.saveClientTokenSetup(
                serverURL: serverURL,
                tokenName: tokenInfo.name,
                version: detectedServerVersion ?? "unknown",
                allowIncompatibleVersionLogin: didAcceptIncompatibleVersion
            )
            Logger.auth.info("Client token pairing complete")
            appViewModel.appData.isLoading = false
            appViewModel.appData.errorMessage = nil
            // Trigger app state transition to authenticated
            await appViewModel.checkInitialState()
        } catch {
            Logger.auth.error("Client token pairing failed: \(error)")
            clientTokenError = error.localizedDescription
        }
        isExchangingToken = false
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func insertText(_ text: String) {
        serverURL += text
    }

    private func seedUITestLoginStateIfNeeded() {
        guard shouldShowLoginForUITests else {
            return
        }

        if serverURL.isEmpty {
            serverURL = "https://demo.romm.app"
        }

        if username.isEmpty {
            username = "snapshot-user"
        }

        if password.isEmpty {
            password = "snapshot-password"
        }

        detectedServerVersion = "3.0.0"
        serverValidated = true
        connectionError = nil
        connectionErrorDetails = nil
        isVersionWarning = false
    }
}

// MARK: - QuickInputChip Component
struct QuickInputChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
                .cornerRadius(12)
        }
    }
}

// MARK: - Connection Debug Panel
struct ConnectionDebugPanel: View {
    let logs: [ConnectionLogEntry]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "ant.fill")
                        .foregroundColor(.secondary)
                    Text("Connection Details")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logs) { log in
                                ConnectionLogRow(entry: log)
                                    .id(log.id)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: logs.count) { _, _ in
                        if let lastLog = logs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Connection Log Row
struct ConnectionLogRow: View {
    let entry: ConnectionLogEntry

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)

            Image(systemName: entry.type.icon)
                .font(.caption)
                .foregroundColor(entry.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)

                if let details = entry.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
