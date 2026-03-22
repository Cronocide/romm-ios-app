# Client Token Auth Integration — Design Spec

## Overview

Integrate RomM's new Client API Token system (PR #3114) into the iOS app as a third authentication method alongside Classic (username/password) and OIDC. Users can pair their device via QR code scanning or manual token input. Tokens are stored securely in the iOS Keychain.

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

**QR Scan & Pairing:**
- `scanQRCode()` — Opens AVCaptureSession, extracts 8-character pairing code
- `handleDeepLink(url: URL) -> String?` — Parses `romm://pair?code=XXXXXXXX`, returns code
- `exchangeCode(serverURL: String, code: String) async throws -> String` — POST to `/api/client-tokens/exchange`, returns raw token string

**Token Management:**
- `saveToken(_ token: String, info: ClientTokenInfo)` — Token to Keychain, info to Keychain
- `getToken() -> String?` — Read token from Keychain
- `getTokenInfo() -> ClientTokenInfo?` — Read metadata from Keychain
- `clearToken()` — Delete both from Keychain

**Scope Query:**
- `fetchTokenInfo(serverURL: String, token: String) async throws -> ClientTokenInfo` — GET `/api/client-tokens` to retrieve own token details + scopes after pairing

### Network

Uses standalone URLSession calls for `exchangeCode()` and `fetchTokenInfo()` since `RommAPIClient` is not yet configured at pairing time. Same pattern as `OIDCAuthService` for discovery/exchange.

### Error Types

```swift
enum ClientTokenError: Error {
    case invalidQRCode            // QR doesn't contain a valid pairing code
    case codeExpired              // 60s TTL exceeded
    case codeInvalid              // Server rejected the code
    case exchangeFailed(String)   // Network/server error during exchange
    case tokenSaveFailed          // Keychain write failure
    case scopeFetchFailed         // Could not retrieve token info
    case cameraUnavailable        // No camera access
}
```

---

## 3. RommAPIClient Integration

### Auth Header

In `makeAuthHeader()` (existing method), add third branch:

```
if authMethod == .clientToken:
    return "Bearer \(clientToken)"    // rmm_... prefix included in token
```

No changes to existing Classic or OIDC branches.

### TokenProvider Extensions

New methods on `TokenProvider`:
- `getClientToken() -> String?` — Reads from Keychain via KeychainService
- `getClientTokenInfo() -> ClientTokenInfo?` — Reads metadata
- `hasScope(_ scope: String) -> Bool` — Checks if current token has a given scope
- `availableScopes: [String]?` — Computed from stored ClientTokenInfo

Existing `getAuthToken()` gets a third branch for `.clientToken` that delegates to `getClientToken()`.

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

"Token verbinden" presents two options:

1. **"QR-Code scannen"** — Opens `QRScannerView` (camera)
2. **"Token eingeben"** — TextField for manual paste

Both converge at the same point: raw token string obtained → save to Keychain → fetch token info/scopes → complete setup.

### QRScannerView (new)

`romm/UI/App/QRScannerView.swift`

- UIViewRepresentable wrapping AVCaptureSession
- Camera preview with scanning overlay
- Detects QR codes, extracts 8-char pairing code
- Calls `ClientTokenAuthService.exchangeCode()` automatically
- Shows spinner during exchange, error on failure

### Deep Link Handling

`AppDelegate` extended to handle `romm://pair?code=XXXXXXXX`:
- Parse code from URL
- If SetupView is active → trigger exchange flow
- If app is already configured → ignore (token management happens in web UI)

### Scope-Based UI Adaptation

After successful pairing, scopes are stored. UI components check scopes:
- Upload/write features hidden when `roms.write` not in scopes
- Admin features hidden when `users.read`/`users.write` not in scopes
- Read-only mode when only `roms.read` present

Implementation: `TokenProvider.hasScope(_:)` queried by ViewModels. No new UI for scope display — features just appear or disappear.

---

## 5. KeychainService

### Generalized API

Extend existing `KeychainService` with generic methods:

```swift
func save(key: String, data: Data) throws
func read(key: String) -> Data?
func delete(key: String)
```

These wrap the existing Keychain access patterns already used for SFTP credentials.

### Keys

- `romm.clientToken` — Token string
- `romm.clientTokenInfo` — JSON-encoded ClientTokenInfo

### Error Handling

Keychain access failure (e.g., device locked, background state) → `sessionExpired` notification, consistent with other auth failures.

### Future Migration Path

The generic API is designed so Classic credentials and OIDC tokens can be migrated to Keychain later. No migration code now — just the foundation.

---

## 6. Server Capability Detection

### AuthCapabilities (new, replaces enum)

```swift
struct AuthCapabilities {
    let classic: Bool
    let oidc: Bool
    let clientTokens: Bool
    let cloudflareBlocked: Bool
}
```

Replaces the existing `AuthCapability` enum to support three independent auth methods.

### Detection Logic

In `HeartbeatRepository.detectAuthCapability()`:

1. Fetch heartbeat response
2. Check for `CLIENT_TOKENS.ENABLED` field in response (or equivalent)
3. If field absent (older server) → `clientTokens: false`
4. Fallback: version comparison if heartbeat doesn't expose the field

### SetupView Adaptation

SetupView switches from `switch authCapability` to checking individual flags on `AuthCapabilities`. Shows all available auth options as buttons/sections.

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
| `Data/Services/KeychainService.swift` | Modified | Generic save/read/delete API |
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
