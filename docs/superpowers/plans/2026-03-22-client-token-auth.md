# Client Token Auth Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Client API Token authentication as a third auth method in the iOS app, with QR pairing and manual token input.

**Architecture:** New `ClientTokenAuthService` handles pairing/exchange/storage (following `OIDCAuthService` pattern). `RommAPIClient.makeBasicAuthHeader()` is refactored into `makeAuthHeader()` dispatching on auth method. `HeartbeatRepository.ServerAuthCapability` enum replaced with `AuthCapabilities` struct. Token stored in Keychain via existing `KeychainService`.

**Tech Stack:** Swift, SwiftUI, AVFoundation (camera), Keychain Services

**Spec:** `docs/superpowers/specs/2026-03-22-client-token-auth-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `romm/romm/Data/API/AuthMethod.swift` | Modify | Add `.clientToken` case + update helpers |
| `romm/romm/Data/API/Models/ClientTokenInfo.swift` | Create | Token metadata model |
| `romm/romm/Data/API/Models/HeartbeatResponse.swift` | Modify | Add optional `CLIENT_TOKENS` field for forward compat |
| `romm/romm/Services/ClientTokenAuthService.swift` | Create | Pairing, exchange, validation, Keychain storage |
| `romm/romm/Data/API/RommAPIClient.swift` | Modify | Refactor auth header, add `makeAuthHeader()` |
| `romm/romm/Data/Services/TokenProvider.swift` | Modify | Add client token methods + scope awareness |
| `romm/romm/Domain/RepositoryProtocols/PHeartbeatRepository.swift` | Modify | Update protocol return type |
| `romm/romm/Data/Repositories/HeartbeatRepository.swift` | Modify | `AuthCapabilities` struct, detection logic |
| `romm/romm/Data/Repositories/SetupRepository.swift` | Modify | Client token persistence helpers + cleanup |
| `romm/romm/UI/App/QRScannerView.swift` | Create | Camera QR scanner (UIViewRepresentable) |
| `romm/romm/UI/App/SetupView.swift` | Modify | Third auth option, pairing sub-flow |
| `romm/romm/AppDelegate.swift` | Modify | Deep link routing for `romm://pair` |
| `romm/romm/Info.plist` | Modify | Add `NSCameraUsageDescription` |

**Deferred to a future task:** Scope-based UI adaptation (hiding features when scopes are missing). The `hasScope()` infrastructure is built here but not yet wired into ViewModels.

---

### Task 1: Data Model — AuthMethod + ClientTokenInfo

**Files:**
- Modify: `romm/romm/Data/API/AuthMethod.swift`
- Create: `romm/romm/Data/API/Models/ClientTokenInfo.swift`

- [ ] **Step 1: Add `.clientToken` case to `AuthMethod`**

In `AuthMethod.swift`, add the new case and update all switch statements:

```swift
// Add case after .oidc:
case clientToken

// Update displayName:
case .clientToken:
    return "API Token"

// Update description:
case .clientToken:
    return "Connect with an API token from your server"

// Update iconName:
case .clientToken:
    return "key.fill"

// Update requiresBrowser:
case .clientToken:
    return false

// Update storesCredentials:
case .clientToken:
    return false // Token stored in Keychain, not as credential
```

- [ ] **Step 2: Update `AuthMethod.recommendation(for:)` and `availableMethods(for:)` temporarily**

These methods take `ServerAuthCapability` which will be replaced in Task 5. For now, make them compile by adding a comment and keeping existing logic. They will be refactored in Task 5.

- [ ] **Step 3: Create `ClientTokenInfo.swift`**

Create `romm/romm/Data/API/Models/ClientTokenInfo.swift`:

```swift
//
//  ClientTokenInfo.swift
//  romm
//

import Foundation

struct ClientTokenInfo: Codable {
    let tokenId: Int
    let name: String
    let scopes: [String]
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}
```

- [ ] **Step 4: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Data/API/AuthMethod.swift romm/romm/Data/API/Models/ClientTokenInfo.swift
git commit -m "feat: add clientToken auth method case and ClientTokenInfo model"
```

---

### Task 2: ClientTokenAuthService — Core Service

**Files:**
- Create: `romm/romm/Services/ClientTokenAuthService.swift`

- [ ] **Step 1: Create `ClientTokenError` enum and `ClientTokenAuthService` class**

Create `romm/romm/Services/ClientTokenAuthService.swift`:

```swift
//
//  ClientTokenAuthService.swift
//  romm
//

import Foundation

enum ClientTokenError: LocalizedError {
    case invalidQRCode
    case codeExpired
    case codeInvalid
    case exchangeFailed(String)
    case tokenInvalid
    case tokenSaveFailed
    case scopeFetchFailed
    case cameraUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidQRCode:
            return "Invalid QR code — not a valid pairing code"
        case .codeExpired:
            return "Pairing code has expired. Please generate a new one."
        case .codeInvalid:
            return "Invalid pairing code"
        case .exchangeFailed(let detail):
            return "Token exchange failed: \(detail)"
        case .tokenInvalid:
            return "Token is invalid or expired"
        case .tokenSaveFailed:
            return "Failed to save token securely"
        case .scopeFetchFailed:
            return "Failed to retrieve token permissions"
        case .cameraUnavailable:
            return "Camera is not available"
        case .rateLimited:
            return "Too many attempts. Please wait a moment."
        }
    }
}

class ClientTokenAuthService {
    private let logger = Logger.auth
    private let keychainService: PKeychainService

    static let tokenKeychainKey = "romm.clientToken"
    static let tokenInfoKeychainKey = "romm.clientTokenInfo"

    init(keychainService: PKeychainService = KeychainService.setup) {
        self.keychainService = keychainService
    }
}
```

- [ ] **Step 2: Add deep link parsing**

```swift
// MARK: - Deep Link Handling

extension ClientTokenAuthService {
    /// Parse a `romm://pair?code=XXXXXXXX` URL and extract the pairing code
    func handleDeepLink(url: URL) -> String? {
        guard url.scheme == "romm",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              code.count == 8 else {
            logger.warning("Invalid pairing deep link: \(url.absoluteString)")
            return nil
        }
        logger.info("Parsed pairing code from deep link")
        return code
    }
}
```

- [ ] **Step 3: Add code exchange (pairing flow)**

```swift
// MARK: - Pairing Flow

extension ClientTokenAuthService {
    /// Exchange an 8-char pairing code for an rmm_ token
    func exchangeCode(serverURL: String, code: String) async throws -> String {
        logger.info("Exchanging pairing code...")

        let cleanURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanURL)/api/client-tokens/exchange") else {
            throw ClientTokenError.exchangeFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)

        let sessionDelegate = PrivateNetworkURLSessionDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientTokenError.exchangeFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                throw ClientTokenError.exchangeFailed("No token in response")
            }
            logger.info("Pairing code exchanged successfully")
            return token
        case 404, 410:
            throw ClientTokenError.codeExpired
        case 400:
            throw ClientTokenError.codeInvalid
        case 429:
            throw ClientTokenError.rateLimited
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClientTokenError.exchangeFailed("Server returned \(httpResponse.statusCode): \(msg)")
        }
    }
}
```

- [ ] **Step 4: Add direct token validation**

```swift
// MARK: - Direct Token Validation

extension ClientTokenAuthService {
    /// Validate a directly-entered rmm_ token and retrieve its metadata
    func validateToken(serverURL: String, token: String) async throws -> ClientTokenInfo {
        logger.info("Validating client token...")

        let cleanURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanURL)/api/client-tokens") else {
            throw ClientTokenError.tokenInvalid
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        let sessionDelegate = PrivateNetworkURLSessionDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientTokenError.tokenInvalid
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Token validation failed: \(httpResponse.statusCode)")
            throw ClientTokenError.tokenInvalid
        }

        // Parse the response to find our token's info
        // The endpoint returns a list of the user's tokens
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tokens = try decoder.decode([ClientTokenResponse].self, from: data)
            // The token we just used to authenticate — find it by matching
            // Limitation: we pick the first token. If user has multiple tokens,
            // a /api/client-tokens/me endpoint would be needed for exact matching.
            guard let tokenInfo = tokens.first else {
                throw ClientTokenError.scopeFetchFailed
            }
            logger.info("Token validated successfully: \(tokenInfo.name)")
            return ClientTokenInfo(
                tokenId: tokenInfo.id,
                name: tokenInfo.name,
                scopes: tokenInfo.scopes.components(separatedBy: " "),
                expiresAt: tokenInfo.expires_at
            )
        } catch is DecodingError {
            logger.error("Failed to decode token info")
            throw ClientTokenError.scopeFetchFailed
        }
    }

    /// Fetch token info after pairing (same endpoint, different entry point)
    func fetchTokenInfo(serverURL: String, token: String) async throws -> ClientTokenInfo {
        return try await validateToken(serverURL: serverURL, token: token)
    }
}

/// Server response model for client token list
private struct ClientTokenResponse: Codable {
    let id: Int
    let name: String
    let scopes: String
    let expires_at: Date?
}
```

- [ ] **Step 5: Add Keychain token management**

```swift
// MARK: - Token Storage

extension ClientTokenAuthService {
    func saveToken(_ token: String, info: ClientTokenInfo) throws {
        logger.info("Saving client token to Keychain...")

        do {
            try keychainService.save(key: Self.tokenKeychainKey, value: token)

            let jsonData = try JSONEncoder().encode(info)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ClientTokenError.tokenSaveFailed
            }
            try keychainService.save(key: Self.tokenInfoKeychainKey, value: jsonString)

            logger.info("Client token saved successfully")
        } catch {
            logger.error("Failed to save client token: \(error)")
            throw ClientTokenError.tokenSaveFailed
        }
    }

    func getToken() -> String? {
        return keychainService.get(key: Self.tokenKeychainKey)
    }

    func getTokenInfo() -> ClientTokenInfo? {
        guard let jsonString = keychainService.get(key: Self.tokenInfoKeychainKey),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(ClientTokenInfo.self, from: jsonData)
    }

    func clearToken() {
        logger.info("Clearing client token from Keychain...")
        try? keychainService.delete(key: Self.tokenKeychainKey)
        try? keychainService.delete(key: Self.tokenInfoKeychainKey)
    }
}
```

- [ ] **Step 6: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add romm/romm/Services/ClientTokenAuthService.swift
git commit -m "feat: add ClientTokenAuthService with pairing, validation, and Keychain storage"
```

---

### Task 3: Refactor RommAPIClient Auth Header

**Files:**
- Modify: `romm/romm/Data/API/RommAPIClient.swift`
- Modify: `romm/romm/Data/Services/TokenProvider.swift`

- [ ] **Step 1: Add client token methods to `PTokenProvider` protocol**

In `romm/romm/Data/Services/TokenProvider.swift`, add to the `PTokenProvider` protocol (after OIDC methods):

```swift
// Client Token Methods
func getClientToken() -> String?
func getClientTokenInfo() -> ClientTokenInfo?
func hasScope(_ scope: String) -> Bool
var availableScopes: [String]? { get }
```

- [ ] **Step 2: Implement client token methods in `TokenProvider`**

Add after the OIDC methods section in `TokenProvider`:

```swift
// MARK: - Client Token Methods

func getClientToken() -> String? {
    logger.debug("Getting client token...")
    let service = ClientTokenAuthService()
    guard let token = service.getToken() else {
        logger.debug("No client token found")
        return nil
    }
    logger.info("Client token found")
    return token
}

func getClientTokenInfo() -> ClientTokenInfo? {
    let service = ClientTokenAuthService()
    return service.getTokenInfo()
}

func hasScope(_ scope: String) -> Bool {
    guard let scopes = availableScopes else { return true } // No scopes = full access (classic/OIDC)
    return scopes.contains(scope)
}

var availableScopes: [String]? {
    guard getAuthMethod() == .clientToken else { return nil }
    return getClientTokenInfo()?.scopes
}
```

- [ ] **Step 3: Update `isConfigured()` to handle client tokens**

In `TokenProvider.isConfigured()`, update to also check for client token auth:

```swift
func isConfigured() -> Bool {
    let authMethod = getAuthMethod()

    if authMethod == .clientToken {
        let hasToken = getClientToken() != nil
        let hasServerURL = getServerURL() != nil
        let configured = hasToken && hasServerURL
        logger.info("Client token configuration check - Token: \(hasToken), Server: \(hasServerURL), Configured: \(configured)")
        return configured
    }

    let hasUsername = getUsername() != nil
    let hasPassword = getPassword() != nil
    let hasServerURL = getServerURL() != nil
    let configured = hasUsername && hasPassword && hasServerURL

    logger.info("Configuration check - Username: \(hasUsername), Password: \(hasPassword), Server: \(hasServerURL), Configured: \(configured)")
    return configured
}
```

- [ ] **Step 4: Update `MockTokenProvider` to conform**

Add to `MockTokenProvider`:

```swift
var mockClientToken: String?
var mockClientTokenInfo: ClientTokenInfo?

func getClientToken() -> String? {
    return mockClientToken
}

func getClientTokenInfo() -> ClientTokenInfo? {
    return mockClientTokenInfo
}

func hasScope(_ scope: String) -> Bool {
    guard let scopes = availableScopes else { return true }
    return scopes.contains(scope)
}

var availableScopes: [String]? {
    return mockClientTokenInfo?.scopes
}
```

- [ ] **Step 5: Replace `makeBasicAuthHeader()` with `makeAuthHeader()`**

In `RommAPIClient.swift`, replace the `makeBasicAuthHeader()` method (lines 489-501) with:

```swift
func makeAuthHeader() throws -> String {
    let authMethod = tokenProvider.getAuthMethod()

    switch authMethod {
    case .clientToken:
        guard let token = tokenProvider.getClientToken() else {
            logger.error("No client token available")
            throw APIClientError.noCredentials
        }
        return "Bearer \(token)"

    case .oidc:
        guard let accessToken = tokenProvider.getOIDCAccessToken() else {
            logger.error("No OIDC access token available")
            throw APIClientError.noCredentials
        }
        return "Bearer \(accessToken)"

    case .classic:
        guard let username = tokenProvider.getUsername(),
              let password = tokenProvider.getPassword() else {
            logger.error("No authentication credentials available")
            throw APIClientError.noCredentials
        }
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            logger.error("Failed to encode credentials")
            throw APIClientError.authenticationRequired
        }
        return "Basic \(loginData.base64EncodedString())"
    }
}
```

- [ ] **Step 6: Update `makeRequest()` to use `makeAuthHeader()`**

In `makeRequest(path:method:body:)` (line 172), replace:
```swift
let base64Auth = try makeBasicAuthHeader()
```
with:
```swift
let authHeader = try makeAuthHeader()
```

And line 176, replace:
```swift
request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
```
with:
```swift
request.setValue(authHeader, forHTTPHeaderField: "Authorization")
```

- [ ] **Step 7: Update `downloadFile()` to use `makeAuthHeader()`**

In `downloadFile(path:progressHandler:)` (line 258), replace:
```swift
let base64Auth = try makeBasicAuthHeader()
```
with:
```swift
let authHeader = try makeAuthHeader()
```

And line 262, replace:
```swift
request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
```
with:
```swift
request.setValue(authHeader, forHTTPHeaderField: "Authorization")
```

- [ ] **Step 8: Update `multipartRequest()` to use `makeAuthHeader()`**

In `multipartRequest(...)` (line 362), replace:
```swift
let base64Auth = try makeBasicAuthHeader()
```
with:
```swift
let authHeader = try makeAuthHeader()
```

And line 367, replace:
```swift
request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
```
with:
```swift
request.setValue(authHeader, forHTTPHeaderField: "Authorization")
```

- [ ] **Step 9: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add romm/romm/Data/API/RommAPIClient.swift romm/romm/Data/Services/TokenProvider.swift
git commit -m "refactor: replace makeBasicAuthHeader with makeAuthHeader dispatching on auth method"
```

---

### Task 4: SetupRepository — Client Token Persistence

**Files:**
- Modify: `romm/romm/Data/Repositories/SetupRepository.swift`

- [ ] **Step 1: Add client token methods to `PSetupRepository` protocol**

In `SetupRepository.swift`, add to the `PSetupRepository` protocol:

```swift
// Client Token Methods
func saveClientTokenSetup(serverURL: String, tokenName: String, version: String, allowIncompatibleVersionLogin: Bool) throws
func clearClientTokenData() throws
```

- [ ] **Step 2: Implement in `SetupRepository`**

Add to the class implementation:

```swift
// MARK: - Client Token Methods

func saveClientTokenSetup(serverURL: String, tokenName: String, version: String, allowIncompatibleVersionLogin: Bool) throws {
    logger.info("Saving client token setup configuration...")

    // Create a SetupConfiguration with token name as username placeholder
    let setupConfig = SetupConfiguration(
        serverURL: serverURL,
        username: tokenName.isEmpty ? "Token User" : tokenName,
        password: nil,
        token: nil, // Token is in Keychain, not here
        refreshToken: nil,
        setupDate: Date(),
        version: version,
        allowIncompatibleVersionLogin: allowIncompatibleVersionLogin
    )

    try saveSetupConfiguration(setupConfig)
    try saveAuthMethod(.clientToken)

    logger.info("Client token setup saved")
}

func clearClientTokenData() throws {
    logger.info("Clearing client token data...")
    let service = ClientTokenAuthService()
    service.clearToken()
    logger.info("Client token data cleared")
}
```

- [ ] **Step 3: Wire cleanup into `clearSetupConfiguration()`**

In `SetupRepository.clearSetupConfiguration()`, add client token cleanup so that re-setup clears old token data:

```swift
func clearSetupConfiguration() throws {
    logger.info("Clearing setup configuration...")

    // Clear client token data from Keychain if present
    if getAuthMethod() == .clientToken {
        try clearClientTokenData()
    }

    // Clear JSON configuration from UserDefaults
    // UserDefaults.standard.removeObject(forKey: setupConfigurationKey)

    logger.info("Setup configuration cleared")
}
```

- [ ] **Step 4: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Data/Repositories/SetupRepository.swift
git commit -m "feat: add client token persistence and cleanup to SetupRepository"
```

---

### Task 5: HeartbeatRepository — AuthCapabilities

**Files:**
- Modify: `romm/romm/Data/Repositories/HeartbeatRepository.swift`
- Modify: `romm/romm/Domain/RepositoryProtocols/PHeartbeatRepository.swift`
- Modify: `romm/romm/Data/API/AuthMethod.swift`
- Modify: `romm/romm/UI/App/SetupView.swift`

- [ ] **Step 1: Add `AuthCapabilities` struct to `HeartbeatRepository.swift`**

Add alongside (not replacing yet) the existing `ServerAuthCapability` enum:

```swift
struct AuthCapabilities {
    let classic: Bool
    let oidc: Bool
    let clientTokens: Bool
    let cloudflareBlocked: Bool
    let unreachable: Bool

    /// Convert from legacy enum for compatibility during migration
    init(from legacy: ServerAuthCapability, clientTokens: Bool = false) {
        switch legacy {
        case .classicOnly:
            self.init(classic: true, oidc: false, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
        case .oidcOnly:
            self.init(classic: false, oidc: true, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
        case .both:
            self.init(classic: true, oidc: true, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
        case .cloudflareBlocked:
            self.init(classic: false, oidc: false, clientTokens: false, cloudflareBlocked: true, unreachable: false)
        case .unreachable:
            self.init(classic: false, oidc: false, clientTokens: false, cloudflareBlocked: false, unreachable: true)
        }
    }

    init(classic: Bool, oidc: Bool, clientTokens: Bool, cloudflareBlocked: Bool, unreachable: Bool) {
        self.classic = classic
        self.oidc = oidc
        self.clientTokens = clientTokens
        self.cloudflareBlocked = cloudflareBlocked
        self.unreachable = unreachable
    }

    var description: String {
        if unreachable { return "Server unreachable" }
        if cloudflareBlocked { return "Server blocked by Cloudflare" }
        var methods: [String] = []
        if classic { methods.append("Classic") }
        if oidc { methods.append("OIDC") }
        if clientTokens { methods.append("Client Tokens") }
        return methods.isEmpty ? "No auth methods available" : methods.joined(separator: ", ")
    }

    var supportsClassic: Bool { classic }
    var supportsOIDC: Bool { oidc }
    var supportsClientTokens: Bool { clientTokens }
}
```

- [ ] **Step 2: Add optional `CLIENT_TOKENS` to `HeartbeatResponse`**

In `romm/romm/Data/API/Models/HeartbeatResponse.swift`, add an optional field for forward compatibility. The server may or may not include this field depending on version:

First, create a new dict type. Add to a new section or inline:

```swift
public struct ClientTokensDict: Codable, JSONEncodable, Hashable {
    public var ENABLED: Bool

    public init(ENABLED: Bool) {
        self.ENABLED = ENABLED
    }
}
```

Then in `HeartbeatResponse`, add an optional property:

```swift
public var CLIENT_TOKENS: ClientTokensDict?
```

Update the `CodingKeys` enum to include `CLIENT_TOKENS`, and update the custom `encode(to:)` to use `encodeIfPresent`. Add a custom `init(from:)` that uses `decodeIfPresent` for `CLIENT_TOKENS` so older servers that don't include this field don't cause decoding failures.

- [ ] **Step 3: Add new `detectAuthCapabilities()` method**

Add a new method that returns `AuthCapabilities`:

```swift
func detectAuthCapabilities(serverURL: String) async -> AuthCapabilities {
    let legacy = await detectAuthCapability(serverURL: serverURL)

    // Check if we got a heartbeat response with CLIENT_TOKENS info
    var hasClientTokens = false
    do {
        let response = try await apiClient.getHeartbeat(from: serverURL)
        if let clientTokensConfig = response.CLIENT_TOKENS {
            hasClientTokens = clientTokensConfig.ENABLED
            oidcLogger.info("Client tokens enabled: \(hasClientTokens)")
        } else {
            oidcLogger.info("Server does not expose CLIENT_TOKENS in heartbeat (older version)")
        }
    } catch {
        oidcLogger.debug("Could not check client token support: \(error)")
    }

    return AuthCapabilities(from: legacy, clientTokens: hasClientTokens)
}
```

- [ ] **Step 4: Update `PHeartbeatRepository` protocol**

Add to the protocol:

```swift
func detectAuthCapabilities(serverURL: String) async -> HeartbeatRepository.AuthCapabilities
```

- [ ] **Step 5: Update `AuthMethod` helper methods**

In `AuthMethod.swift`, add new overloads that work with `AuthCapabilities`:

```swift
static func recommendation(for capabilities: HeartbeatRepository.AuthCapabilities) -> String {
    if capabilities.unreachable {
        return "Server is unreachable"
    }
    if capabilities.cloudflareBlocked {
        return "Server is protected and requires OIDC configuration"
    }
    return "Choose your preferred authentication method"
}

static func availableMethods(for capabilities: HeartbeatRepository.AuthCapabilities) -> [AuthMethod] {
    var methods: [AuthMethod] = []
    if capabilities.classic { methods.append(.classic) }
    if capabilities.oidc { methods.append(.oidc) }
    if capabilities.clientTokens { methods.append(.clientToken) }
    return methods
}
```

- [ ] **Step 6: Update `SetupView` to use `AuthCapabilities`**

In `SetupView.swift`, change the state variable (line 28):

```swift
@State private var detectedAuthCapability: HeartbeatRepository.AuthCapabilities?
```

Update `detectAuthenticationMethod()` to use the new method:

```swift
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

    // Default auth method selection
    if capabilities.oidc {
        selectedAuthMethod = .oidc
        await discoverOIDCConfiguration()
    } else if capabilities.classic {
        selectedAuthMethod = .classic
    } else if capabilities.clientTokens {
        selectedAuthMethod = .clientToken
    }
}
```

Update `authMethodPicker` (line 282) to show when multiple methods available:

```swift
if let capability = detectedAuthCapability {
    let methods = AuthMethod.availableMethods(for: capability)
    if methods.count > 1 {
        authMethodPicker
    }
}
```

Update the `loginSection` to handle `.clientToken`:

Add after the OIDC info section:

```swift
// Client Token Info (if clientToken selected)
if selectedAuthMethod == .clientToken {
    clientTokenAuthSection
}
```

- [ ] **Step 7: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add romm/romm/Data/API/Models/HeartbeatResponse.swift romm/romm/Data/Repositories/HeartbeatRepository.swift romm/romm/Domain/RepositoryProtocols/PHeartbeatRepository.swift romm/romm/Data/API/AuthMethod.swift romm/romm/UI/App/SetupView.swift
git commit -m "feat: add AuthCapabilities struct and update SetupView for three auth methods"
```

---

### Task 6: SetupView — Client Token Pairing UI

**Files:**
- Modify: `romm/romm/UI/App/SetupView.swift`

- [ ] **Step 1: Add client token state variables**

Add to the state variables section of `SetupView`:

```swift
// Client Token states
@State private var clientTokenInput = ""
@State private var isExchangingToken = false
@State private var clientTokenError: String?
@State private var showQRScanner = false
```

- [ ] **Step 2: Add `clientTokenAuthSection` view**

Add a new computed property to `SetupView`:

```swift
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

        // QR Scan Button
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

        // Divider with "or"
        HStack {
            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)
            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
        }

        // Manual Token Input
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste Token")
                .font(.headline)
            TextField("rmm_...", text: $clientTokenInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.body, design: .monospaced))
        }

        // Error
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
```

- [ ] **Step 3: Update `loginButton` for client token**

In `loginButton` action (line 378), add the client token case:

```swift
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
}
```

Update the label to handle client token:

```swift
} else {
    HStack {
        Image(systemName: selectedAuthMethod.iconName)
        Text(selectedAuthMethod == .oidc ? "Login with Browser" : selectedAuthMethod == .clientToken ? "Connect with Token" : "Login")
    }
}
```

- [ ] **Step 4: Update `canProceedWithLogin`**

```swift
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
```

- [ ] **Step 5: Add `performClientTokenLogin()` and `performClientTokenPairing()`**

Note: These methods modify `@State` properties, so mark them `@MainActor` to avoid SwiftUI threading issues.

```swift
// MARK: - Client Token Login

@MainActor
private func performClientTokenLogin() async {
    isExchangingToken = true
    clientTokenError = nil

    let service = ClientTokenAuthService()

    do {
        // Validate the token
        let tokenInfo = try await service.validateToken(serverURL: serverURL, token: clientTokenInput)

        // Save token to Keychain
        try service.saveToken(clientTokenInput, info: tokenInfo)

        // Save setup configuration
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

        Task { @MainActor in
            appViewModel.appData.isLoading = false
            appViewModel.appData.errorMessage = nil
        }
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
        // Exchange code for token
        let token = try await service.exchangeCode(serverURL: serverURL, code: code)

        // Fetch token info
        let tokenInfo = try await service.fetchTokenInfo(serverURL: serverURL, token: token)

        // Save token to Keychain
        try service.saveToken(token, info: tokenInfo)

        // Save setup configuration
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

        Task { @MainActor in
            appViewModel.appData.isLoading = false
            appViewModel.appData.errorMessage = nil
        }
    } catch {
        Logger.auth.error("Client token pairing failed: \(error)")
        clientTokenError = error.localizedDescription
    }

    isExchangingToken = false
}
```

- [ ] **Step 6: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add romm/romm/UI/App/SetupView.swift
git commit -m "feat: add client token pairing UI to SetupView"
```

---

### Task 7: QR Scanner View

**Files:**
- Create: `romm/romm/UI/App/QRScannerView.swift`
- Modify: `romm/romm/Info.plist`

- [ ] **Step 1: Add `NSCameraUsageDescription` to Info.plist**

Add to `romm/romm/Info.plist` before the closing `</dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes for device pairing</string>
```

- [ ] **Step 2: Create `QRScannerView.swift`**

Create `romm/romm/UI/App/QRScannerView.swift`:

```swift
//
//  QRScannerView.swift
//  romm
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var hasScanned = false

    var body: some View {
        NavigationView {
            ZStack {
                QRCameraPreview(onCodeFound: handleCode)
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        } else {
                            Text("Point your camera at the QR code in RomM settings")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handleCode(_ code: String) {
        guard !hasScanned else { return }

        // Validate it looks like a pairing code (8 alphanumeric chars)
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 8, trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            error = "Not a valid pairing code"
            return
        }

        hasScanned = true
        onCodeScanned(trimmed)
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct QRCameraPreview: UIViewRepresentable {
    let onCodeFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeFound: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?

        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else {
                return
            }
            session?.stopRunning()
            onCodeFound(value)
        }
    }
}
```

- [ ] **Step 3: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/App/QRScannerView.swift romm/romm/Info.plist
git commit -m "feat: add QR scanner view for token pairing"
```

---

### Task 8: AppDelegate — Deep Link Routing

**Files:**
- Modify: `romm/romm/AppDelegate.swift`

- [ ] **Step 1: Update URL handler to route between OIDC and pairing**

Replace the `application(_:open:options:)` method in `AppDelegate.swift`:

```swift
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    Logger.oidc.info("App received URL: \(url.absoluteString)")

    guard url.scheme == "romm" else {
        Logger.oidc.warning("Unknown URL scheme: \(url.scheme ?? "none")")
        return false
    }

    switch url.host {
    case "pair":
        Logger.auth.info("Pairing deep link received")
        let service = ClientTokenAuthService()
        if let code = service.handleDeepLink(url: url) {
            NotificationCenter.default.post(
                name: .clientTokenPairingCode,
                object: nil,
                userInfo: ["code": code]
            )
        }
        return true

    default:
        // OIDC callback or other — ASWebAuthenticationSession handles it
        Logger.oidc.info("OIDC callback URL received")
        return true
    }
}
```

- [ ] **Step 2: Add notification name extension**

Add at the bottom of `AppDelegate.swift`:

```swift
extension Notification.Name {
    static let clientTokenPairingCode = Notification.Name("clientTokenPairingCode")
}
```

- [ ] **Step 3: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add romm/romm/AppDelegate.swift
git commit -m "feat: add deep link routing for romm://pair in AppDelegate"
```

---

### Task 9: Integration — Wire Deep Link to SetupView

**Files:**
- Modify: `romm/romm/UI/App/SetupView.swift`

- [ ] **Step 1: Add deep link listener to SetupView**

Add to `.onAppear` in the `body`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .clientTokenPairingCode)) { notification in
    if let code = notification.userInfo?["code"] as? String {
        Task {
            await performClientTokenPairing(code: code)
        }
    }
}
```

- [ ] **Step 2: Verify project compiles**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add romm/romm/UI/App/SetupView.swift
git commit -m "feat: wire deep link pairing notification to SetupView"
```

---

### Task 10: Final Integration & Xcode Project

**Files:**
- Modify: `romm/romm.xcodeproj/project.pbxproj` (via Xcode build)

- [ ] **Step 1: Ensure all new files are added to the Xcode project**

The new files that need to be in the Xcode project:
- `romm/romm/Data/API/Models/ClientTokenInfo.swift`
- `romm/romm/Services/ClientTokenAuthService.swift`
- `romm/romm/UI/App/QRScannerView.swift`

Run a full build which will fail if files aren't in the project:

```bash
xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

If files are missing from the project, they need to be added via `project.pbxproj`. Check if the project uses file references or a folder reference structure.

- [ ] **Step 2: Full build verification**

Run: `xcodebuild -project romm/romm.xcodeproj -scheme romm -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Final commit**

```bash
git add romm/romm.xcodeproj/project.pbxproj
git commit -m "chore: add new files to Xcode project for client token auth"
```
