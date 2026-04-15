# Client Token Auth Integration — Design Spec

## Overview

Integrate RomM's new Client API Token system (PR #3114) into the iOS app as a third authentication method alongside Classic (username/password) and OIDC. Users can pair their device via QR code scanning, deep link, or direct token input. Tokens are stored securely in the iOS Keychain.

## Context

RomM PR #3114 adds persistent, revocable API tokens with `rmm_` prefix. Tokens support:
- Scoped permissions (intersection with user role)
- Flexible expiry (30/90 days, 1 year, or never)
- QR/short-code pairing with 60-second TTL
- Admin oversight and revocation

The iOS app currently authenticates via Classic (Basic Auth + OAuth2 password grant) or OIDC (Authorization Code + PKCE). Both flows are managed through `TokenProvider`, `SetupRepository`, and `RommAPIClient`.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Relationship to existing auth | Third option alongside Classic + OIDC | No disruption to existing users |
| Server compatibility | Auto-detect via Heartbeat | Graceful degradation for older servers |
| Token storage | Keychain | Secure OS-level encryption; existing KeychainService available |
| Pairing methods | QR scan (camera) + deep link + manual input | Maximum flexibility |
| Token expiry handling | Back to Setup (sessionExpired) | Consistent with existing 401 handling |
| Scope handling | Fetch after pairing, adapt UI | Better UX than showing 403 errors |
| Architecture | Separate ClientTokenAuthService | Follows OIDCAuthService pattern, keeps SetupView manageable |

---

## 1. Data Model

### AuthMethod (existing, extended)

```swift
enum AuthMethod: String, Codable {
    case classic
    case oidc
    case clientToken  // NEW
}
```

### ClientTokenInfo (new)

```swift
struct ClientTokenInfo: Codable {
    let tokenId: Int          // Server-side token ID
    let name: String          // User-friendly label
    let scopes: [String]      // Granted scopes
    let expiresAt: Date?      // nil = perpetual
}
```

### Storage

| Data | Location | Key |
|------|----------|-----|
| Token string (`rmm_...`) | Keychain | `romm.clientToken` |
| ClientTokenInfo (JSON) | Keychain | `romm.clientTokenInfo` |
| AuthMethod | UserDefaults | `setup_auth_method` (existing key) |
| Server URL | UserDefaults | Existing `SetupConfiguration` |

---

## 2. ClientTokenAuthService

New service file: `romm/Services/ClientTokenAuthService.swift`

### Responsibilities

**Pairing (8-char code → token exchange):**
- `scanQRCode()` — Opens AVCaptureSession, extracts 8-character pairing code from QR
- `handleDeepLink(url: URL) -> String?` — Parses `romm://pair?code=XXXXXXXX`, returns 8-char pairing code
- `exchangeCode(serverURL: String, code: String) async throws -> String` — POST to `/api/client-tokens/exchange` with pairing code, returns raw `rmm_` token string

**Direct Token Input (user already has a token):**
- `validateToken(serverURL: String, token: String) async throws -> ClientTokenInfo` — GET `/api/client-tokens` with the token as Bearer header to verify it works and retrieve metadata. Throws if token is invalid/expired.

**Token Management:**
- `saveToken(_ token: String, info: ClientTokenInfo)` — Token to Keychain, info to Keychain
- `getToken() -> String?` — Read token from Keychain
- `getTokenInfo() -> ClientTokenInfo?` — Read metadata from Keychain
- `clearToken()` — Delete both from Keychain

**Scope Query:**
- `fetchTokenInfo(serverURL: String, token: String) async throws -> ClientTokenInfo` — GET `/api/client-tokens` to retrieve own token details + scopes. Used after both pairing and direct input paths.

### Network

Uses standalone URLSession calls for `exchangeCode()` and `fetchTokenInfo()` since `RommAPIClient` is not yet configured at pairing time. Same pattern as `OIDCAuthService` for discovery/exchange.

### Error Types

```swift
enum ClientTokenError: Error {
    case invalidQRCode            // QR doesn't contain a valid pairing code
    case codeExpired              // 60s TTL exceeded
    case codeInvalid              // Server rejected the code
    case exchangeFailed(String)   // Network/server error during exchange
    case tokenInvalid             // Direct-input token failed validation
    case tokenSaveFailed          // Keychain write failure
    case scopeFetchFailed         // Could not retrieve token info
    case cameraUnavailable        // No camera access
    case rateLimited              // 429 from exchange endpoint (5 req/min/IP)
}
```

---

## 3. RommAPIClient Integration

### Auth Header Refactoring

The current codebase hardcodes `"Basic \(base64Auth)"` in three places: `makeRequest()`, `downloadFile()`, and `multipartRequest()`, each calling `makeBasicAuthHeader()`. This must be refactored:

1. **Replace `makeBasicAuthHeader()`** with a new `makeAuthHeader() -> String?` method that dispatches based on auth method:
   - `.classic` → `"Basic \(base64)"` (existing logic)
   - `.oidc` → `"Bearer \(oidcAccessToken)"` (existing logic)
   - `.clientToken` → `"Bearer \(clientToken)"` (rmm_ prefix included in token)
2. **Update all three request methods** (`makeRequest`, `downloadFile`, `multipartRequest`) to call `makeAuthHeader()` instead of hardcoding Basic auth
3. **Handle missing credentials gracefully**: For `.clientToken`, if Keychain read fails → throw `APIClientError.noCredentials` (same as existing behavior for missing username/password)

### TokenProvider & PTokenProvider Protocol

Both `PTokenProvider` protocol and `TokenProvider` implementation must be updated:

New protocol methods:
- `getClientToken() -> String?` — Reads from Keychain via KeychainService
- `getClientTokenInfo() -> ClientTokenInfo?` — Reads metadata
- `hasScope(_ scope: String) -> Bool` — Checks if current token has a given scope
- `availableScopes: [String]?` — Computed from stored ClientTokenInfo

Existing `getAuthToken()` gets a third branch for `.clientToken` that delegates to `getClientToken()`.

Note: `MockTokenProvider` (used in tests/previews) must also be updated to conform to the new protocol.

### 401 Handling

No changes. Existing `sessionExpired` notification flow handles token auth identically — 401 response → post notification → SetupView presented.

---

## 4. SetupView & UI

### Auth Option Selection

After server validation and capability detection, SetupView shows available auth methods. When `capabilities.clientTokens == true`:

- **"Username & Password"** (if classic available)
- **"Browser Login"** (if OIDC available)
- **"Token verbinden"** (if client tokens available) — NEW

### Token Pairing Sub-Flow

"Token verbinden" presents two options with distinct flows:

**Path A: QR-Code scannen (pairing code flow)**
1. Camera opens → scans QR → extracts 8-char pairing code
2. `exchangeCode()` POSTs code to `/api/client-tokens/exchange` → receives `rmm_` token
3. `fetchTokenInfo()` validates token and retrieves scopes
4. Save token + info to Keychain → complete setup

**Path B: Token eingeben (direct token flow)**
1. User pastes full `rmm_` token string from web UI
2. `validateToken()` calls GET `/api/client-tokens` with token as Bearer header → verifies token works, retrieves scopes
3. Save token + info to Keychain → complete setup

Both paths converge after step 2: validated token + ClientTokenInfo → save → complete setup.

Note: `SetupConfiguration.username` is currently non-optional. For client token auth, populate with the token name or "Token User" (similar to OIDC's fallback of `tokens.username ?? "OIDC User"`).

### QRScannerView (new)

`romm/UI/App/QRScannerView.swift`

- UIViewRepresentable wrapping AVCaptureSession
- Camera preview with scanning overlay
- Detects QR codes, extracts 8-char pairing code
- Calls `ClientTokenAuthService.exchangeCode()` automatically
- Shows spinner during exchange, error on failure

### Deep Link Handling

`AppDelegate` already handles `romm://` URLs for OIDC callbacks (`romm://callback`). Extended to route based on host/path:

- `romm://callback?...` → existing OIDC flow (unchanged)
- `romm://pair?code=XXXXXXXX` → new client token pairing flow

Routing logic in `AppDelegate.application(_:open:options:)`:
1. Parse URL host: `"callback"` → OIDC, `"pair"` → client token
2. For `"pair"`: extract `code` query parameter → forward to `ClientTokenAuthService.handleDeepLink()`
3. If SetupView is active → trigger exchange flow
4. If app is already configured → ignore (token management happens in web UI)

### Scope-Based UI Adaptation

After successful pairing, scopes are stored. UI components check scopes:
- Upload/write features hidden when `roms.write` not in scopes
- Admin features hidden when `users.read`/`users.write` not in scopes
- Read-only mode when only `roms.read` present

Implementation: `TokenProvider.hasScope(_:)` queried by ViewModels. No new UI for scope display — features just appear or disappear.

---

## 5. KeychainService

### Using Existing API

`KeychainService` already has String-based methods: `save(key:value:)`, `get(key:) -> String?`, `delete(key:)`. Use these directly:

- Token string (`rmm_...`) → `save(key: "romm.clientToken", value: tokenString)`
- ClientTokenInfo → JSON-encode to String, then `save(key: "romm.clientTokenInfo", value: jsonString)`

No new methods needed. The existing API is sufficient.

### Keys

- `romm.clientToken` — Token string
- `romm.clientTokenInfo` — JSON-encoded ClientTokenInfo

### Error Handling

Keychain access failure (e.g., device locked, background state) → `sessionExpired` notification, consistent with other auth failures.

### Future Migration Path

The generic API is designed so Classic credentials and OIDC tokens can be migrated to Keychain later. No migration code now — just the foundation.

---

## 6. Server Capability Detection

### AuthCapabilities (new, replaces ServerAuthCapability enum)

```swift
struct AuthCapabilities {
    let classic: Bool
    let oidc: Bool
    let clientTokens: Bool
    let cloudflareBlocked: Bool
    let unreachable: Bool
}
```

Replaces the existing `ServerAuthCapability` enum (which has cases: `classicOnly`, `oidcOnly`, `both`, `cloudflareBlocked`, `unreachable`) to support three independent auth methods plus error states.

### Migration of Existing Call Sites

The following must be updated when replacing the enum:
- `AuthMethod.recommendation(for:)` and `AuthMethod.availableMethods(for:)` in `AuthMethod.swift` — switch from enum matching to flag checking
- `SetupView` `@State private var detectedAuthCapability` — change type to `AuthCapabilities?`
- `HeartbeatRepository.detectAuthCapability()` — return `AuthCapabilities` instead of enum

### Detection Logic

In `HeartbeatRepository.detectAuthCapability()`:

1. Fetch heartbeat response
2. Check for client token support:
   - **Primary**: Check if heartbeat response contains a client tokens field (to be verified against the exact server response shape from PR #3114 during implementation)
   - **Fallback**: Version comparison — if server version >= the release that includes PR #3114, assume client tokens are available
   - **Default**: If neither signal is present → `clientTokens: false`
3. Existing classic/OIDC detection logic unchanged
4. Note: The exact heartbeat response field name must be confirmed during implementation by checking the merged PR #3114 server code

### SetupView Adaptation

SetupView switches from `switch authCapability` to checking individual flags on `AuthCapabilities`. Shows all available auth options as buttons/sections. Error states (`cloudflareBlocked`, `unreachable`) take precedence and show appropriate messaging before auth options.

---

## Files Changed / Created

| File | Action | Description |
|------|--------|-------------|
| `Data/API/AuthMethod.swift` | Modified | Add `.clientToken` case |
| `Data/API/Models/ClientTokenInfo.swift` | New | Token metadata model |
| `Services/ClientTokenAuthService.swift` | New | Pairing, exchange, storage, scope logic |
| `UI/App/QRScannerView.swift` | New | Camera-based QR scanner |
| `Data/API/RommAPIClient.swift` | Modified | Third auth header branch |
| `Data/Services/TokenProvider.swift` | Modified | Client token + scope methods |
| `Data/Services/KeychainService.swift` | Unchanged | Existing String API is sufficient |
| `Domain/RepositoryProtocols/PTokenProvider.swift` | Modified | Add client token protocol methods |
| `Data/Repositories/HeartbeatRepository.swift` | Modified | AuthCapabilities struct, client token detection |
| `Data/Repositories/SetupRepository.swift` | Modified | Client token persistence helpers |
| `UI/App/SetupView.swift` | Modified | Third auth option, pairing sub-flow |
| `AppDelegate.swift` | Modified | Deep link handler for `romm://pair` |
| `Info.plist` | Modified | Camera usage description (NSCameraUsageDescription) |

---

## Out of Scope

- Token creation/management in the iOS app (done in web UI)
- Automatic token refresh (client tokens don't have refresh flow)
- Migration of existing Classic/OIDC credentials to Keychain (future work)
- Batch token operations
- Admin token management from the iOS app
