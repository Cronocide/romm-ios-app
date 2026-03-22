# Cloudflare & OIDC Detection

## 🎯 Überblick

Die App kann jetzt automatisch erkennen, ob ein Server hinter Cloudflare geschützt ist und ob OIDC/SSO verfügbar ist.

## 📋 Implementierte Features

### 1. **Cloudflare Detection** ✅
In `RommAPIClient.swift`:
- Erkennt Cloudflare-Headers (`cf-*`)
- Prüft Server-Header auf "cloudflare"
- Analysiert Response-Body nach Challenge-Seiten ("Just a moment", etc.)
- Wirft `APIClientError.cloudflareProtection` wenn erkannt

### 2. **OIDC Discovery** ✅
In `RommAPIClient.swift`:
- Prüft `/.well-known/openid-configuration` Endpoint
- 5 Sekunden Timeout
- Kein Auth nötig (public endpoint)
- Returns `true` wenn verfügbar

### 3. **Server Capability Detection** ✅
In `HeartbeatRepository.swift`:
- Enum `ServerAuthCapability`:
  - `.classicOnly` - Nur Username/Password
  - `.oidcOnly` - Nur OIDC (Cloudflare aktiv)
  - `.both` - Beide Methoden verfügbar
  - `.cloudflareBlocked` - Cloudflare aber kein OIDC
  - `.unreachable` - Server nicht erreichbar

- Methode `detectAuthCapability(serverURL:)`:
  1. Versucht Heartbeat (testet Classic Auth + Cloudflare)
  2. Prüft OIDC-Verfügbarkeit
  3. Kombiniert Ergebnisse zu Capability

### 4. **SetupView Integration** ✅
In `SetupView.swift`:
- Cloudflare-Errors werden speziell behandelt
- User-freundliche Fehlermeldungen
- Error-Details werden automatisch ausgeklappt
- Vorbereitet für OIDC-Trigger (TODO-Marker gesetzt)

## 🔍 Wie es funktioniert

### Bei Server-Verbindung im Setup:

```
User tippt Server-URL ein
  ↓
Klickt "Connect"
  ↓
validateServer() wird aufgerufen
  ↓
appViewModel.fetchServerVersion() ruft Heartbeat auf
  ↓
RommAPIClient.makeRequest() bekommt 403
  ↓
isCloudflareChallenge() prüft Response
  ↓
Wirft APIClientError.cloudflareProtection
  ↓
SetupView fängt Error und zeigt:
"🔒 Server is protected by Cloudflare
Details: This server requires browser-based authentication (OIDC/SSO)"
```

## 📊 Detection-Logik

### Cloudflare-Fingerprinting:

```swift
Headers:
✓ cf-ray: xxxxx
✓ cf-cache-status: DYNAMIC
✓ server: cloudflare

Body enthält:
✓ "Just a moment..."
✓ "Checking your browser"
✓ "challenge-platform"
✓ "cf-browser-verification"
```

### OIDC-Check:

```swift
GET https://romm.spinnich.net/.well-known/openid-configuration

Status: 200 ✓ → OIDC verfügbar
Status: 404/403/5xx → OIDC nicht verfügbar
```

## 🚀 Nächste Schritte (TODO)

### Phase 2: OIDC Service implementieren
- [ ] `OIDCAuthService.swift` erstellen
- [ ] `ASWebAuthenticationSession` wrapper
- [ ] PKCE-Flow implementieren
- [ ] Token-Exchange mit Backend
- [ ] Token in SetupRepository speichern

### Phase 3: UI für OIDC
- [ ] "Login with Browser" Button in SetupView
- [ ] Auth-Method Selector (Classic vs OIDC)
- [ ] Loading-States für Browser-Auth
- [ ] Success/Error-Handling nach OIDC-Flow

### Phase 4: Auto-Trigger
- [ ] Bei `.cloudflareProtection` Error → OIDC-Button zeigen
- [ ] Optional: Auto-open Browser nach 3 Sekunden
- [ ] User-Präferenz speichern (Classic vs OIDC)
- [ ] Fallback-Logik wenn OIDC fehlschlägt

## 🧪 Testing

### Lokale Tests:
```swift
// In HeartbeatRepository
let capability = await detectAuthCapability(serverURL: "https://romm.spinnich.net")

switch capability {
case .classicOnly:
    print("✅ Classic auth works")
case .oidcOnly:
    print("🔒 Need OIDC - Cloudflare active")
case .both:
    print("✅ Both methods available")
case .cloudflareBlocked:
    print("❌ Cloudflare without OIDC")
case .unreachable:
    print("❌ Server down")
}
```

### Im Setup:
1. Gib `https://romm.spinnich.net` ein
2. Klick "Connect"
3. Sollte Cloudflare-Error zeigen mit Details

## 📝 Logs

Die Detection loggt jeden Schritt:
```
🔍 Detecting authentication capabilities for: https://romm.spinnich.net
🔒 Cloudflare protection detected
❌ OIDC is not available
⚠️ Result: Server blocked by Cloudflare, no OIDC configured
```

## 🔑 Error Codes

| Error | Bedeutung | User Action |
|-------|-----------|-------------|
| `cloudflareProtection` | 403 von Cloudflare | Warten auf OIDC-Integration |
| `oidcRequired` | Server braucht OIDC | OIDC-Flow nutzen (TODO) |
| `authenticationRequired` | 401 Unauthorized | Credentials prüfen |
| `invalidResponse` | Andere HTTP-Errors | Server-Config prüfen |

## 🎨 UI States

**Vor Connect:**
```
┌─────────────────────┐
│  Server URL         │
│  [https://...]      │
│  [Connect]          │
└─────────────────────┘
```

**Während Connect:**
```
┌─────────────────────┐
│  Server URL         │
│  [https://...]      │
│  [⏳ Connecting...] │
└─────────────────────┘
```

**Bei Cloudflare:**
```
┌─────────────────────────────────┐
│  Server URL                     │
│  [https://romm.spinnich.net]    │
│  [Change]                       │
│                                 │
│  🔒 Server is protected by      │
│     Cloudflare                  │
│  ⌄ This server requires         │
│    browser-based auth (OIDC)    │
│                                 │
│  [ TODO: Login with Browser ]   │
└─────────────────────────────────┘
```

**Bei Success:**
```
┌─────────────────────┐
│  Server URL ✓ v4.5  │
│  [https://...]      │
│  [Change]           │
│                     │
│  Username           │
│  [...]              │
│                     │
│  Password           │
│  [...]              │
│                     │
│  [Login]            │
└─────────────────────┘
```

## 💡 Hinweise

- Die Detection funktioniert **ohne Credentials** (public endpoints)
- Cloudflare-Check passiert bei **jedem 403**
- OIDC-Check hat 5 Sekunden Timeout
- Logs gehen in `Logger.network` und `Logger.data`
- Error-Details werden automatisch ausgeklappt bei Cloudflare

## 🐛 Troubleshooting

**Cloudflare wird nicht erkannt:**
- Check Logs für Header-Dump
- Prüf ob Response-Body "Just a moment" enthält
- Test mit `isCloudflareChallenge()` direkt

**OIDC-Check dauert zu lange:**
- Timeout ist 5 Sekunden
- Server antwortet evtl. nicht auf `.well-known`
- Check Logs: "OIDC discovery check failed"

**Setup zeigt falschen Error:**
- `parseConnectionError()` in SetupView prüfen
- APIClientError-Case hinzufügen falls nötig
- Error-Mapping in `parseGeneralConnectionError()`

---

Made with ☕ in Bremen
