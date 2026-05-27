# DeltaCore Integration — Design Spec

- **Datum:** 2026-05-15
- **Branch:** `feature/deltacore-integration`
- **Status:** Draft (Review-Gate offen)

## Ziel

Native Emulation von ROMs aus dem ROMM-Server in der romm-App über
[`rileytestut/DeltaCore`](https://github.com/rileytestut/DeltaCore) und die zugehörigen Core-Pakete
einführen. Erster unterstützter Core: **GBA** (`GBADeltaCore`). Architektur ist darauf ausgelegt,
weitere Cores (NES, SNES, GBC, N64, MelonDS/DS, GPGX/Genesis) ohne Umbauten zu ergänzen.

Die bestehende WebView-/EmulatorJS-Lösung bleibt parallel bestehen und wird per Setting wählbar
("Emulator Engine"). Default ist zunächst **Web**, damit die native Lösung schrittweise gegen
die etablierte WebView-Variante getestet werden kann.

## Nicht-Ziele (Out of Scope MVP)

- Server-Sync von Save States und Battery-Saves nach ROMM (`/api/states`, `/api/saves`).
  Hook ist über `SaveStore`-Protokoll offen, MVP implementiert nur `LocalSaveStore`.
- Custom Touch-Skins im romm-Look (kommt später als Phase 2).
- Cheats, Fast-Forward, Rewind, Cloud-Backup von Saves.
- Cores außer GBA. Architektur ist generisch, Implementierung erfolgt inkrementell.
- Auto-Engine-Routing per `PlatformEngineSupport`. Der Mechanismus ist im Design enthalten
  (Settings-Option "Auto"), wird aber im MVP nur als Wert-Stub gepflegt; UI bleibt initial
  bei den expliziten Optionen "Web" und "DeltaCore". "Auto" wird mit dem zweiten Core scharf
  geschaltet.

## Annahmen

- iOS Deployment Target der App ist 18.6, DeltaCore verlangt iOS 14+ → kompatibel.
- DeltaCore-Lizenz (AGPL-Kette) ist mit dem Maintainer geklärt und für dieses Projekt akzeptabel.
- `LocalROMRepository`, `DownloadedROM`, `LaunchEmulatorUseCase` und die FileSystem-UseCases
  existieren bereits und liefern ROM-Dateien lokal aus dem Documents-Bereich.
- ROMM-Plattform-Slugs entsprechen den in der App bereits genutzten Werten
  (z. B. `"gba"` für Game Boy Advance).

## Architektur

```
UI Layer
├── EmulatorRouterView          (neu) — entscheidet anhand Setting Web vs. Native
├── EmulatorView                (bestehend, WebView/EmulatorJS — unverändert)
└── DeltaEmulatorView           (neu) — SwiftUI-Wrapper um DLTAGameViewController

Domain Layer
├── EmulatorEngine              (neu, enum: .web / .deltaCore / .auto)
├── EmulatorEnginePreference    (neu, in UserDefaults persistiert, Default .web)
├── PlatformEngineSupport       (neu) — welche Engines unterstützen welchen platformSlug?
├── SaveStore (Protocol)        (neu) — Battery + State CRUD
│   └── LocalSaveStore          (neu)
└── LaunchEmulatorUseCase       (erweitert) — gibt LaunchDecision zurück

DeltaCore-Adapter Layer (neu, isoliert DeltaCore-Imports vom Rest der App)
├── DeltaCoreSession            — wrappt EmulatorCore + DLTAGameViewController + Lifecycle
├── PlatformSlugToGameType      — z. B. "gba" → GBA.gameType
└── ROMFileResolver             — DownloadedROM → Datei-URL, die DeltaCore frisst

Settings
└── "Emulator Engine" Picker    — Optionen: Web / DeltaCore (MVP); später Auto

Dependencies (SPM)
├── github.com/rileytestut/DeltaCore                 (offiziell, SPM-fertig)
└── github.com/<user>/GBADeltaCore (Fork mit Package.swift)   (MVP)
    [später: NES/SNES/GBC/N64/MelonDS/GPGX-Forks analog]
```

### Datenfluss (Launch)

```
1. RomDetailView "Play" tap
   └── LaunchEmulatorUseCase.execute(rom) -> LaunchDecision
       ├── Pre-Flight (Server, Plattform, Filename) — bestehend
       └── Engine bestimmen:
           ├── Preference = .web        → LaunchDecision.web(rom)
           ├── Preference = .deltaCore  → LaunchDecision.deltaCore(rom, gameType)
           └── Preference = .auto       → PlatformEngineSupport.preferred(slug)
                                          (MVP: fällt auf .web zurück)

2. EmulatorRouterView empfängt LaunchDecision
   ├── .web        → EmulatorView(rom: rom)              (bestehend, unverändert)
   └── .deltaCore  → DeltaEmulatorView(rom: rom, gameType: gameType)

3. DeltaEmulatorView Setup
   ├── LocalROMRepository.localFileURL(romId)
   │     vorhanden: weiter
   │     fehlt: Fehlerdialog "ROM bitte zuerst herunterladen" mit CTA → Download
   ├── ROMFileResolver wählt passende Datei aus DownloadedROM.files
   ├── DeltaCoreSession(gameURL, gameType, saveStore: LocalSaveStore(romId))
   │   ├── EmulatorCore(game: DLTAGame(fileURL, type))
   │   ├── Default-Skin aus GBADeltaCore-Bundle (Fallback: App-Bundle, siehe R2)
   │   └── pre-load Battery-Save (falls vorhanden)
   └── eingebettet via UIViewControllerRepresentable

4. Runtime
   ├── Render via Metal in DLTAGameView
   ├── Touch-Input via Default-Skin
   ├── MFi-Controller via DeltaCore.ExternalGameControllerManager
   └── Save State Menü → LocalSaveStore.writeState(romId, slot, data)

5. Exit
   ├── EmulatorCore.stop()
   ├── Battery-Save flushen → LocalSaveStore.writeBattery(romId, data)
   └── Cleanup
```

### Lokales Save-Layout

```
Documents/Saves/
└── <romId>/
    ├── battery.sav
    └── states/
        ├── 1.dltastate
        └── 2.dltastate
```

## Komponenten

| Komponente | Größe (ca.) | In | Out / Zweck |
|---|---|---|---|
| `DeltaCoreSession` | ~150 LOC | `gameURL`, `gameType`, `saveStore` | `DLTAGameViewController`, `start/pause/resume/stop`, `saveStateToSlot`, `loadStateFromSlot`. Kapselt alle DeltaCore-Imports. |
| `PlatformSlugToGameType` | ~30 LOC + Tests | `platformSlug: String` | `GameType?` (MVP: nur `"gba"`) |
| `PlatformEngineSupport` | ~40 LOC + Tests | `platformSlug` | `Set<EmulatorEngine>` + `preferred(slug)` |
| `SaveStore` (Protocol) | ~30 LOC | — | API für Battery/State CRUD |
| `LocalSaveStore` | ~120 LOC + Tests | `romId`, FS-UseCases | Implementiert `SaveStore` über `Documents/Saves/` |
| `EmulatorEnginePreference` | ~40 LOC | — | Persistiert Setting in `UserDefaults` |
| `DeltaEmulatorView` | ~80 LOC | `rom`, `gameType` | SwiftUI-View; `UIViewControllerRepresentable` |
| `EmulatorRouterView` | ~30 LOC | `rom`, `LaunchDecision` | Routet auf `EmulatorView` oder `DeltaEmulatorView` |
| `LaunchEmulatorUseCase` (Erw.) | +30 LOC | `rom` | Neuer Return-Typ `LaunchDecision` |
| `ROMFileResolver` | ~40 LOC + Tests | `DownloadedROM`, `gameType` | passende Datei-URL oder Error |

## Test-Strategie

| Komponente | Test-Art |
|---|---|
| `PlatformSlugToGameType` | Pure Unit Test |
| `PlatformEngineSupport` | Pure Unit Test |
| `ROMFileResolver` | Unit Test mit Fixture-Daten |
| `LocalSaveStore` | Integration in `tmp`-Verzeichnis |
| `EmulatorEnginePreference` | Unit Test mit Mock-`UserDefaults` |
| `LaunchEmulatorUseCase` (Erw.) | Unit Test, Mocks für Preference + Support |
| `DeltaCoreSession` | Smoke-Test (UIKit+Metal nicht sinnvoll mockbar) |
| `DeltaEmulatorView` | Manueller Test im Simulator/Device |

TDD wo möglich: alle Mapper, Stores und der erweiterte UseCase werden test-first geschrieben.

## Risiken & Mitigation

- **R1 (mittel) — GBADeltaCore-Fork baut nicht out-of-the-box.** Der Core enthält C/Obj-C
  (VBA-M) und braucht ggf. ein speziell konfiguriertes `Package.swift`
  (`publicHeadersPath`, `exclude`, Resource-Copies). **Mitigation:** Spike-Task vor dem
  vollständigen Implementierungsplan — Fork anlegen, minimales `Package.swift` schreiben,
  Verifikation, dass das Paket als SPM-Dependency in einer leeren iOS-App startet.
- **R2 (niedrig) — Default-GBA-Skin liegt evtl. nicht im Core-Bundle.** **Mitigation:** Im
  Spike auch das Skin-Resource-Setup prüfen; ggf. einen minimalen Skin aus dem Delta-App-Repo
  als Fallback ins App-Bundle ziehen.
- **R3 (niedrig) — `DownloadedROM.files` enthält ggf. mehrere oder gepackte Dateien.**
  **Mitigation:** `ROMFileResolver` wählt erste passende Endung (`.gba`); Error wenn keine
  passt; ZIP-Auspackung (falls nötig) später ergänzen.
- **R4 (mittel) — AGPLv3-Lizenzkette muss in der App ausgewiesen werden.** **Mitigation:**
  ein Lizenz-Eintrag pro genutztem Core in Settings/Licenses-Screen, plus Hinweis im
  Repository (LICENSE-NOTICE).
- **R5 (offen) — Performance auf älteren Geräten.** Mit Deployment Target iOS 18.6
  (iPhone XS aufwärts) realistisch unkritisch; im manuellen Test verifizieren.

## Phasen-Plan (Grobskizze)

1. **Spike** — `GBADeltaCore`-Fork mit `Package.swift`, einbinden in eine Sandbox, Hello-ROM
   startet. Falls Spike scheitert: zurück zu Approach (B) Git-Submodules.
2. **Domain-Skelett** — `EmulatorEngine`, `EmulatorEnginePreference`, `PlatformEngineSupport`,
   `SaveStore`-Protokoll, `LocalSaveStore`, `PlatformSlugToGameType`, `ROMFileResolver`
   inkl. Tests. Reine Logik, kein UI.
3. **UseCase-Erweiterung** — `LaunchEmulatorUseCase` liefert `LaunchDecision`; Tests.
4. **UI-Integration** — `DeltaCoreSession`, `DeltaEmulatorView`, `EmulatorRouterView`; an
   `RomDetailView` anbinden; Settings-Picker "Emulator Engine".
5. **Polish** — Fehlerbehandlung (keine ROM lokal), Lifecycle (Pause beim Backgrounding),
   AGPL-Lizenztexte in Settings, Logging-Anbindung.

Die einzelnen Phasen werden im nachfolgenden Implementation-Plan in konkrete Tasks zerlegt.

## Offene Punkte für Implementation-Plan

- Genaue API-Form des `DeltaCoreSession` (öffentliche Methoden vs. Properties).
- Verhalten bei Engine-Wechsel während laufender Session (vermutlich verbieten /
  Session beenden).
- UI-Strings (DE/EN — die App ist mehrsprachig?).
