# DeltaCore Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native ROM-Emulation via DeltaCore (Phase 1: GBA) parallel zur bestehenden WebView/EmulatorJS-Lösung; per Settings-Picker wählbar.

**Architektur:** Domain-Layer trifft Engine-Entscheidung im erweiterten `LaunchEmulatorUseCase`. Ein neuer `EmulatorRouterView` routet anhand des Ergebnisses entweder auf die bestehende `EmulatorView` (WebView) oder die neue `DeltaEmulatorView`. Ein isolierter `DeltaCoreSession`-Adapter kapselt alle DeltaCore-Importe; das restliche App-Codebase importiert kein DeltaCore-Symbol direkt. Lokale Saves/States landen in `Documents/Saves/<romId>/` über ein `SaveStore`-Protokoll (MVP-Implementierung: `LocalSaveStore`).

**Tech Stack:** Swift 5+, SwiftUI, iOS 18.6+, Swift Testing Framework (`Testing`). Dependencies eingebunden über Git-Submodules + Xcode-Subprojekte: `Vendor/DeltaCore` (`github.com/rileytestut/DeltaCore`) und `Vendor/GBADeltaCore` (`github.com/ilyas-hallak/GBADeltaCore`). Kein SPM für die DeltaCore-Kette — GBADeltaCore-Build (VBA-M / C++) ist mit der vorhandenen `.xcodeproj` am robustesten.

**Spec:** `docs/superpowers/specs/2026-05-15-deltacore-integration-design.md`

---

## Phase 0 — DeltaCore via Git-Submodules + Xcode-Subprojekt

**Ziel:** `DeltaCore.framework` und `GBADeltaCore.framework` aus den Submodul-Subprojekten heraus bauen und in die `romm`-App linken. Kein SPM. Kein Package.swift schreiben.

**Begründung:** GBADeltaCore enthält VBA-M (C/C++/Obj-C++) mit verschachtelten Submodulen (visualboyadvance-m, SFML). Eine SPM-Beschreibung wäre brüchig und müsste bei jedem Upstream-Update nachgezogen werden. Die mitgelieferten Xcode-Projekte sind die Single Source of Truth.

**Status (bereits erledigt im aktuellen Branch):**
- `Vendor/DeltaCore` als Submodule (rileytestut/DeltaCore)
- `Vendor/GBADeltaCore` als Submodule (ilyas-hallak/GBADeltaCore)
- `git submodule update --init --recursive` ist gelaufen (inkl. ZIPFoundation, visualboyadvance-m, dependencies)
- Pfad-Layout: `GBADeltaCore.xcodeproj` referenziert `../DeltaCore/DeltaCore.xcodeproj` — durch das `Vendor/`-Layout korrekt auflösbar.

### Task 0.1: GBADeltaCore.xcodeproj ins romm-Workspace integrieren

**Manuelle Xcode-Schritte (kein Subagent kann das tun):**

- [ ] **Step 1: Xcode öffnen**

```bash
open romm/romm.xcodeproj
```

- [ ] **Step 2: GBADeltaCore.xcodeproj per Drag & Drop ins Project Navigator ziehen**

Im Finder navigieren zu `Vendor/GBADeltaCore/GBADeltaCore.xcodeproj` und in der Xcode-Project-Navigator-Liste (linke Spalte) auf **gleicher Hierarchie-Ebene wie `romm.xcodeproj`** loslassen — also als Geschwister, NICHT ins `romm`-Projekt hinein.

Dialog "Choose options": `Copy items if needed` **ausschalten** (Submodul soll referenziert, nicht kopiert werden). `Create groups`. Add to targets: KEINE Targets (Häkchen alle entfernen — Linking machen wir im nächsten Schritt manuell).

Im Anschluss zieht Xcode `DeltaCore.xcodeproj` automatisch als Nested-Subprojekt mit ein, weil GBADeltaCore.xcodeproj es referenziert.

- [ ] **Step 3: Build Phase "Link Binary With Libraries" am `romm`-Target ergänzen**

`romm` Target → Tab **General** → Sektion **Frameworks, Libraries, and Embedded Content** → **+** → in der Liste auswählen:
- `DeltaCore.framework` (aus dem Subprojekt)
- `GBADeltaCore.framework` (aus dem Subprojekt)

Bei beiden **Embed: "Embed & Sign"** wählen.

- [ ] **Step 4: Target-Dependencies setzen**

`romm` Target → Tab **Build Phases** → Abschnitt **Dependencies** → **+** → `GBADeltaCore` (das Framework-Target des Subprojekts) hinzufügen.

(GBADeltaCore hat seinerseits bereits `DeltaCore` als Dependency — dadurch ist die Reihenfolge korrekt.)

- [ ] **Step 5: Deployment-Target prüfen**

`romm` ist auf iOS 18.6. `DeltaCore` und `GBADeltaCore` müssen ≤ 18.6 sein (Submodul-Default ist iOS 14). Falls Xcode einen Mismatch meldet: in den Sub-Projekt-Targets das iOS Deployment Target auf 14 belassen (kompatibel mit 18.6).

- [ ] **Step 6: Build verifizieren**

Im Xcode Schema-Picker `romm` auswählen, Destination iPhone 17 Simulator, `Product → Build` (cmd+B).

Erwartet: ** BUILD SUCCEEDED **. Falls Fehler:
- "Module 'DeltaCore' not found": Frameworks-Section in General nochmal prüfen, ggf. Clean Build Folder (cmd+shift+K) + Derived Data löschen.
- C++/header search path Fehler im VBA-M-Build: nicht anfassen — sollten durch das mitgelieferte `.xcodeproj` korrekt gesetzt sein. Im Zweifel `Vendor/GBADeltaCore` Submodul auf den Upstream-HEAD aktualisieren.

- [ ] **Step 7: Smoke-Test ohne ROM**

Eine Datei `romm/romm/UI/Emulator/DeltaCoreSmokeTest.swift` (temporär, in Phase 3 wieder gelöscht) anlegen:

```swift
import DeltaCore
import GBADeltaCore

enum DeltaCoreSmokeTest {
    static func ping() -> String {
        return "DeltaCore loaded. GBA gameType id: \(GBA.gameType.rawValue)"
    }
}
```

Erfolgskriterium: Datei compiliert. Damit ist der Import-Pfad ins App-Target nachgewiesen. Nach Phase 3 wieder löschen.

- [ ] **Step 8: Commit (pbxproj-Änderungen)**

Xcode hat `romm/romm.xcodeproj/project.pbxproj` modifiziert. Diese Änderungen committen — zusammen mit den bereits gestageten Submodul-Referenzen:

```bash
git add .gitmodules Vendor/DeltaCore Vendor/GBADeltaCore romm/romm.xcodeproj/project.pbxproj romm/romm/UI/Emulator/DeltaCoreSmokeTest.swift
git commit -m "feat: integrate DeltaCore and GBADeltaCore as Xcode subprojects"
```

### Task 0.2: Spike-Findings dokumentieren

- [ ] **Step 1: Im Design-Spec einen Anhang anhängen**

`docs/superpowers/specs/2026-05-15-deltacore-integration-design.md` → neuer Abschnitt am Ende:

```markdown
## Anhang — Phase-0-Findings

- Integrationsweg: Git-Submodules `Vendor/DeltaCore` und `Vendor/GBADeltaCore`, eingebunden als Xcode-Subprojekte.
- DeltaCore: rileytestut/DeltaCore (SHA: <sha>)
- GBADeltaCore-Fork: ilyas-hallak/GBADeltaCore (SHA: <sha>)
- Default-Skin: <vorhanden im Core-Bundle / Fallback nötig> — siehe `Vendor/GBADeltaCore/GBADeltaCore/Standard.deltaskin`
- Initializer-Signaturen für Phase 3:
  - `Game(fileURL:, type:)` — `<fertige Signatur einfügen>`
  - `EmulatorCore(game:)` — `<…>`
  - `GameViewController` / `DLTAGameViewController` — `<…>`
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-05-15-deltacore-integration-design.md
git commit -m "docs: document Phase 0 DeltaCore integration findings"
```

---

## Phase 1 — Domain-Skelett (reine Logik + Tests)

Setzt Spike erfolgreich voraus. Diese Phase nutzt DeltaCore noch NICHT — alle Tasks sind pure Swift ohne DeltaCore-Imports, damit der Domain-Layer unabhängig testbar bleibt.

### Task 1.1: `EmulatorEngine` Enum

**Files:**
- Create: `romm/romm/Domain/Models/EmulatorEngine.swift`
- Test: `romm/rommTests/EmulatorEngineTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
@testable import romm

struct EmulatorEngineTests {
    @Test func rawValuesArePersisted() {
        #expect(EmulatorEngine.web.rawValue == "web")
        #expect(EmulatorEngine.deltaCore.rawValue == "deltaCore")
        #expect(EmulatorEngine.auto.rawValue == "auto")
    }

    @Test func allCasesContainsAllEngines() {
        #expect(EmulatorEngine.allCases.count == 3)
    }
}
```

- [ ] **Step 2: Tests laufen lassen → fail**

In Xcode: `cmd+U` für `rommTests`. Erwartet: Fehler "EmulatorEngine not found".

- [ ] **Step 3: Implementierung**

```swift
import Foundation

enum EmulatorEngine: String, CaseIterable, Codable, Sendable {
    case web
    case deltaCore
    case auto
}
```

- [ ] **Step 4: Tests laufen lassen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Domain/Models/EmulatorEngine.swift romm/rommTests/EmulatorEngineTests.swift
git commit -m "feat: add EmulatorEngine enum"
```

### Task 1.2: `EmulatorEnginePreference` (UserDefaults-backed)

**Files:**
- Create: `romm/romm/Domain/Models/EmulatorEnginePreference.swift`
- Test: `romm/rommTests/EmulatorEnginePreferenceTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
import Foundation
@testable import romm

struct EmulatorEnginePreferenceTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultIsWeb() {
        let defaults = makeDefaults()
        let pref = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref.current == .web)
    }

    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let pref1 = EmulatorEnginePreference(userDefaults: defaults)
        pref1.current = .deltaCore
        let pref2 = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref2.current == .deltaCore)
    }

    @Test func unknownRawValueFallsBackToWeb() {
        let defaults = makeDefaults()
        defaults.set("xxx", forKey: "emulator.engine.preference")
        let pref = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref.current == .web)
    }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung**

```swift
import Foundation

protocol PEmulatorEnginePreference: AnyObject {
    var current: EmulatorEngine { get set }
}

final class EmulatorEnginePreference: PEmulatorEnginePreference {
    private let key = "emulator.engine.preference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var current: EmulatorEngine {
        get {
            guard let raw = userDefaults.string(forKey: key),
                  let engine = EmulatorEngine(rawValue: raw) else {
                return .web
            }
            return engine
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: key)
        }
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Domain/Models/EmulatorEnginePreference.swift romm/rommTests/EmulatorEnginePreferenceTests.swift
git commit -m "feat: add EmulatorEnginePreference"
```

### Task 1.3: `PlatformEngineSupport`

**Files:**
- Create: `romm/romm/Domain/UseCases/Emulator/PlatformEngineSupport.swift`
- Test: `romm/rommTests/PlatformEngineSupportTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
@testable import romm

struct PlatformEngineSupportTests {
    @Test func gbaSupportsBothEngines() {
        let support = PlatformEngineSupport()
        let engines = support.supportedEngines(for: "gba")
        #expect(engines.contains(.deltaCore))
        #expect(engines.contains(.web))
    }

    @Test func psxOnlySupportsWeb() {
        let support = PlatformEngineSupport()
        let engines = support.supportedEngines(for: "psx")
        #expect(engines.contains(.web))
        #expect(!engines.contains(.deltaCore))
    }

    @Test func unknownPlatformReturnsEmpty() {
        let support = PlatformEngineSupport()
        #expect(support.supportedEngines(for: "xyz").isEmpty)
    }

    @Test func preferredFallsBackToWebForGBA() {
        let support = PlatformEngineSupport()
        #expect(support.preferred(for: "gba") == .web)
    }

    @Test func slugIsCaseInsensitive() {
        let support = PlatformEngineSupport()
        #expect(support.supportedEngines(for: "GBA").contains(.deltaCore))
    }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung**

```swift
import Foundation

protocol PPlatformEngineSupport {
    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine>
    func preferred(for platformSlug: String) -> EmulatorEngine
}

final class PlatformEngineSupport: PPlatformEngineSupport {
    // Web-Engine wird aus CheckEmulatorSupportUseCase abgeleitet (alle dort gelisteten Slugs).
    // DeltaCore: aktuell nur GBA (MVP). Beim Hinzufügen neuer Cores hier ergänzen.
    private let deltaCoreSlugs: Set<String> = ["gba"]

    private let webSupport: PCheckEmulatorSupportUseCase

    init(webSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase()) {
        self.webSupport = webSupport
    }

    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine> {
        let slug = platformSlug.lowercased()
        var result: Set<EmulatorEngine> = []
        if webSupport.execute(platformSlug: slug) { result.insert(.web) }
        if deltaCoreSlugs.contains(slug) { result.insert(.deltaCore) }
        return result
    }

    func preferred(for platformSlug: String) -> EmulatorEngine {
        // MVP-Regel: Auto bevorzugt Web, bis User es ändert (DeltaCore wird scharf
        // geschaltet, sobald >1 Core integriert ist).
        let supported = supportedEngines(for: platformSlug)
        if supported.contains(.web) { return .web }
        return .deltaCore
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Domain/UseCases/Emulator/PlatformEngineSupport.swift romm/rommTests/PlatformEngineSupportTests.swift
git commit -m "feat: add PlatformEngineSupport"
```

### Task 1.4: `SaveStore`-Protokoll + Datentypen

**Files:**
- Create: `romm/romm/Domain/Models/SaveData.swift`
- Create: `romm/romm/Domain/RepositoryProtocols/PSaveStore.swift`

- [ ] **Step 1: Implementierung**

`SaveData.swift`:

```swift
import Foundation

enum SaveKind: Equatable {
    case battery
    case state(slot: Int)
}

struct SaveStateEntry: Equatable, Identifiable {
    let slot: Int
    let modifiedAt: Date
    var id: Int { slot }
}
```

`PSaveStore.swift`:

```swift
import Foundation

protocol PSaveStore {
    func readBattery(romId: Int) throws -> Data?
    func writeBattery(romId: Int, data: Data) throws

    func listStates(romId: Int) throws -> [SaveStateEntry]
    func readState(romId: Int, slot: Int) throws -> Data?
    func writeState(romId: Int, slot: Int, data: Data) throws
    func deleteState(romId: Int, slot: Int) throws
}
```

- [ ] **Step 2: Commit**

```bash
git add romm/romm/Domain/Models/SaveData.swift romm/romm/Domain/RepositoryProtocols/PSaveStore.swift
git commit -m "feat: add SaveStore protocol and types"
```

### Task 1.5: `LocalSaveStore`-Implementierung

**Files:**
- Create: `romm/romm/Data/Repositories/LocalSaveStore.swift`
- Test: `romm/rommTests/LocalSaveStoreTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
import Foundation
@testable import romm

struct LocalSaveStoreTests {

    private func makeStore() -> (LocalSaveStore, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalSaveStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (LocalSaveStore(rootDirectory: tmp), tmp)
    }

    @Test func batteryRoundtrip() throws {
        let (store, _) = makeStore()
        let payload = Data([0xCA, 0xFE])
        try store.writeBattery(romId: 42, data: payload)
        #expect(try store.readBattery(romId: 42) == payload)
    }

    @Test func batteryReturnsNilWhenMissing() throws {
        let (store, _) = makeStore()
        #expect(try store.readBattery(romId: 99) == nil)
    }

    @Test func stateRoundtripAndList() throws {
        let (store, _) = makeStore()
        try store.writeState(romId: 1, slot: 1, data: Data([0x01]))
        try store.writeState(romId: 1, slot: 2, data: Data([0x02]))
        let entries = try store.listStates(romId: 1)
        #expect(entries.map(\.slot).sorted() == [1, 2])
        #expect(try store.readState(romId: 1, slot: 1) == Data([0x01]))
    }

    @Test func deleteState() throws {
        let (store, _) = makeStore()
        try store.writeState(romId: 1, slot: 1, data: Data([0x01]))
        try store.deleteState(romId: 1, slot: 1)
        #expect(try store.readState(romId: 1, slot: 1) == nil)
    }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung**

```swift
import Foundation

final class LocalSaveStore: PSaveStore {
    private let rootDirectory: URL
    private let fileManager = FileManager.default

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    convenience init() {
        let docs = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        self.init(rootDirectory: docs.appendingPathComponent("Saves", isDirectory: true))
    }

    // MARK: - Battery

    func readBattery(romId: Int) throws -> Data? {
        let url = batteryURL(romId: romId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeBattery(romId: Int, data: Data) throws {
        try ensureDir(romId: romId)
        try data.write(to: batteryURL(romId: romId), options: .atomic)
    }

    // MARK: - State

    func listStates(romId: Int) throws -> [SaveStateEntry] {
        let dir = statesDir(romId: romId)
        guard fileManager.fileExists(atPath: dir.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return urls.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "dltastate", let slot = Int(name) else { return nil }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            return SaveStateEntry(slot: slot, modifiedAt: attrs?.contentModificationDate ?? Date())
        }
    }

    func readState(romId: Int, slot: Int) throws -> Data? {
        let url = stateURL(romId: romId, slot: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeState(romId: Int, slot: Int, data: Data) throws {
        try ensureDir(romId: romId)
        let dir = statesDir(romId: romId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: stateURL(romId: romId, slot: slot), options: .atomic)
    }

    func deleteState(romId: Int, slot: Int) throws {
        let url = stateURL(romId: romId, slot: slot)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Paths

    private func romDir(romId: Int) -> URL {
        rootDirectory.appendingPathComponent("\(romId)", isDirectory: true)
    }
    private func statesDir(romId: Int) -> URL {
        romDir(romId: romId).appendingPathComponent("states", isDirectory: true)
    }
    private func batteryURL(romId: Int) -> URL {
        romDir(romId: romId).appendingPathComponent("battery.sav")
    }
    private func stateURL(romId: Int, slot: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("\(slot).dltastate")
    }
    private func ensureDir(romId: Int) throws {
        try fileManager.createDirectory(at: romDir(romId: romId), withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Data/Repositories/LocalSaveStore.swift romm/rommTests/LocalSaveStoreTests.swift
git commit -m "feat: add LocalSaveStore"
```

### Task 1.6: `ROMFileResolver`

**Files:**
- Create: `romm/romm/Domain/UseCases/Emulator/ROMFileResolver.swift`
- Test: `romm/rommTests/ROMFileResolverTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
import Foundation
@testable import romm

struct ROMFileResolverTests {

    private func makeROM(files: [String]) -> DownloadedROM {
        DownloadedROM(
            id: 1, name: "Test", platformName: "Game Boy Advance",
            platformSlug: "gba", downloadedAt: Date(), totalSizeBytes: 0,
            localDirectory: "rom1",
            files: files.map { DownloadedROMFile(fileName: $0, fileSizeBytes: 0) }
        )
    }

    @Test func picksGBAExtension() throws {
        let rom = makeROM(files: ["readme.txt", "Game.gba"])
        let resolver = ROMFileResolver()
        let url = try resolver.resolve(rom: rom, baseURL: URL(fileURLWithPath: "/tmp"), gameType: .gba)
        #expect(url.lastPathComponent == "Game.gba")
    }

    @Test func throwsWhenNoMatch() {
        let rom = makeROM(files: ["readme.txt"])
        let resolver = ROMFileResolver()
        #expect(throws: ROMFileResolverError.self) {
            _ = try resolver.resolve(rom: rom, baseURL: URL(fileURLWithPath: "/tmp"), gameType: .gba)
        }
    }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung**

```swift
import Foundation

enum DeltaGameType: String {
    case gba
    // Phase >1: case nes, snes, gbc, n64, ds, genesis
}

enum ROMFileResolverError: Error, Equatable {
    case noMatchingFile(gameType: DeltaGameType)
}

protocol PROMFileResolver {
    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL
}

final class ROMFileResolver: PROMFileResolver {

    private let extensions: [DeltaGameType: Set<String>] = [
        .gba: ["gba"]
    ]

    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL {
        let allowed = extensions[gameType] ?? []
        let romDir = baseURL.appendingPathComponent(rom.localDirectory, isDirectory: true)
        for file in rom.files {
            let ext = (file.fileName as NSString).pathExtension.lowercased()
            if allowed.contains(ext) {
                return romDir.appendingPathComponent(file.fileName)
            }
        }
        throw ROMFileResolverError.noMatchingFile(gameType: gameType)
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Domain/UseCases/Emulator/ROMFileResolver.swift romm/rommTests/ROMFileResolverTests.swift
git commit -m "feat: add ROMFileResolver"
```

### Task 1.7: `PlatformSlugToGameType`-Mapper

**Files:**
- Create: `romm/romm/Domain/UseCases/Emulator/PlatformSlugToGameType.swift`
- Test: `romm/rommTests/PlatformSlugToGameTypeTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
import Testing
@testable import romm

struct PlatformSlugToGameTypeTests {
    @Test func gbaMaps() { #expect(PlatformSlugToGameType.map("gba") == .gba) }
    @Test func gbaUppercaseMaps() { #expect(PlatformSlugToGameType.map("GBA") == .gba) }
    @Test func unknownReturnsNil() { #expect(PlatformSlugToGameType.map("psx") == nil) }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung**

```swift
import Foundation

enum PlatformSlugToGameType {
    static func map(_ slug: String) -> DeltaGameType? {
        switch slug.lowercased() {
        case "gba", "game boy advance": return .gba
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Commit**

```bash
git add romm/romm/Domain/UseCases/Emulator/PlatformSlugToGameType.swift romm/rommTests/PlatformSlugToGameTypeTests.swift
git commit -m "feat: add PlatformSlugToGameType mapper"
```

---

## Phase 2 — UseCase-Erweiterung

### Task 2.1: `LaunchEmulatorUseCase` mit `LaunchDecision`

**Files:**
- Modify: `romm/romm/Domain/UseCases/Emulator/LaunchEmulatorUseCase.swift`
- Test: `romm/rommTests/LaunchEmulatorUseCaseTests.swift`

- [ ] **Step 1: Tests schreiben (Decision-Pfade)**

```swift
import Testing
@testable import romm

private final class StubPreference: PEmulatorEnginePreference {
    var current: EmulatorEngine
    init(_ engine: EmulatorEngine) { self.current = engine }
}

private final class StubSupport: PPlatformEngineSupport {
    var engines: Set<EmulatorEngine> = []
    func supportedEngines(for platformSlug: String) -> Set<EmulatorEngine> { engines }
    func preferred(for platformSlug: String) -> EmulatorEngine { engines.contains(.web) ? .web : .deltaCore }
}

private final class StubTokenProvider: PTokenProvider {
    var serverURL: String? = "https://server"
    func getServerURL() -> String? { serverURL }
    // Implementiere weitere Methoden minimal — exakte Signatur an PTokenProvider angleichen
}

private final class StubCheckSupport: PCheckEmulatorSupportUseCase {
    var supported = true
    func execute(platformSlug: String) -> Bool { supported }
}

private func makeRom(slug: String = "gba") -> Rom {
    Rom(id: 1, name: "Test", platformId: 0, urlCover: nil,
        isFavourite: false, hasRetroAchievements: false, isPlayable: true,
        fileName: "Test.gba", platformSlug: slug)
}

struct LaunchEmulatorUseCaseTests {
    @Test func failsWhenNoServer() async {
        let token = StubTokenProvider(); token.serverURL = nil
        let useCase = LaunchEmulatorUseCase(
            tokenProvider: token,
            checkEmulatorSupport: StubCheckSupport(),
            enginePreference: StubPreference(.web),
            platformSupport: StubSupport()
        )
        let result = await useCase.execute(rom: makeRom())
        if case .failure(.noServerConfigured) = result {} else { Issue.record("expected .noServerConfigured") }
    }

    @Test func webPreferenceReturnsWebDecision() async {
        let support = StubSupport(); support.engines = [.web]
        let useCase = LaunchEmulatorUseCase(
            tokenProvider: StubTokenProvider(),
            checkEmulatorSupport: StubCheckSupport(),
            enginePreference: StubPreference(.web),
            platformSupport: support
        )
        let result = await useCase.execute(rom: makeRom())
        if case .success(let decision) = result, case .web = decision {} else {
            Issue.record("expected .web decision")
        }
    }

    @Test func deltaPreferenceReturnsDeltaDecisionForGBA() async {
        let support = StubSupport(); support.engines = [.web, .deltaCore]
        let useCase = LaunchEmulatorUseCase(
            tokenProvider: StubTokenProvider(),
            checkEmulatorSupport: StubCheckSupport(),
            enginePreference: StubPreference(.deltaCore),
            platformSupport: support
        )
        let result = await useCase.execute(rom: makeRom(slug: "gba"))
        if case .success(let decision) = result,
           case .deltaCore(_, let gameType) = decision {
            #expect(gameType == .gba)
        } else {
            Issue.record("expected .deltaCore(.gba) decision")
        }
    }

    @Test func deltaPreferenceFallsBackToWebWhenUnsupported() async {
        let support = StubSupport(); support.engines = [.web]
        let useCase = LaunchEmulatorUseCase(
            tokenProvider: StubTokenProvider(),
            checkEmulatorSupport: StubCheckSupport(),
            enginePreference: StubPreference(.deltaCore),
            platformSupport: support
        )
        let result = await useCase.execute(rom: makeRom(slug: "psx"))
        if case .success(let decision) = result, case .web = decision {} else {
            Issue.record("expected fallback to .web")
        }
    }
}
```

- [ ] **Step 2: Tests laufen → fail**

- [ ] **Step 3: Implementierung — Datei umbauen**

`romm/romm/Domain/UseCases/Emulator/LaunchEmulatorUseCase.swift` ersetzen durch:

```swift
import Foundation

enum LaunchDecision {
    case web(rom: Rom)
    case deltaCore(rom: Rom, gameType: DeltaGameType)
}

enum EmulatorLaunchResult {
    case success(LaunchDecision)
    case failure(EmulatorLaunchError)
}

enum EmulatorLaunchError: LocalizedError {
    case noServerConfigured
    case unsupportedPlatform(String)
    case romNotAvailable
    case serverUnreachable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noServerConfigured:
            return "No server configured. Please set up your ROMM server in Settings."
        case .unsupportedPlatform(let platform):
            return "Platform '\(platform)' is not supported for emulation."
        case .romNotAvailable:
            return "ROM file is not available. Please download it first or check your server connection."
        case .serverUnreachable:
            return "Cannot reach ROMM server. Please check your connection."
        case .unknown(let message):
            return message
        }
    }
}

protocol PLaunchEmulatorUseCase {
    func execute(rom: Rom) async -> EmulatorLaunchResult
}

final class LaunchEmulatorUseCase: PLaunchEmulatorUseCase {
    private let tokenProvider: PTokenProvider
    private let checkEmulatorSupport: PCheckEmulatorSupportUseCase
    private let enginePreference: PEmulatorEnginePreference
    private let platformSupport: PPlatformEngineSupport
    private let logger = Logger.viewModel

    init(
        tokenProvider: PTokenProvider = TokenProvider(),
        checkEmulatorSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase(),
        enginePreference: PEmulatorEnginePreference = EmulatorEnginePreference(),
        platformSupport: PPlatformEngineSupport = PlatformEngineSupport()
    ) {
        self.tokenProvider = tokenProvider
        self.checkEmulatorSupport = checkEmulatorSupport
        self.enginePreference = enginePreference
        self.platformSupport = platformSupport
    }

    func execute(rom: Rom) async -> EmulatorLaunchResult {
        guard tokenProvider.getServerURL() != nil else {
            return .failure(.noServerConfigured)
        }
        guard let platformSlug = rom.platformSlug else {
            return .failure(.unsupportedPlatform("Unknown"))
        }
        guard checkEmulatorSupport.execute(platformSlug: platformSlug) else {
            return .failure(.unsupportedPlatform(platformSlug))
        }

        let supported = platformSupport.supportedEngines(for: platformSlug)
        let chosen: EmulatorEngine = {
            switch enginePreference.current {
            case .web: return supported.contains(.web) ? .web : .deltaCore
            case .deltaCore: return supported.contains(.deltaCore) ? .deltaCore : .web
            case .auto: return platformSupport.preferred(for: platformSlug)
            }
        }()

        switch chosen {
        case .web:
            return .success(.web(rom: rom))
        case .deltaCore:
            guard let gameType = PlatformSlugToGameType.map(platformSlug) else {
                return .success(.web(rom: rom))
            }
            return .success(.deltaCore(rom: rom, gameType: gameType))
        case .auto:
            return .success(.web(rom: rom))
        }
    }
}
```

- [ ] **Step 4: Tests laufen → pass**

- [ ] **Step 5: Konsumenten anpassen**

`RomDetailViewModel` und `PlatformROMsListView` (siehe Phase 3) konsumieren nachher `LaunchDecision`. In dieser Task ggf. Build-Fehler durch geänderten Return-Type fixen: alle bisherigen Stellen, die `.success` als parameter-lose Variante prüfen, an die neue Form anpassen (kein vorhandener Stellt das so derzeit, aber Build verifizieren).

```bash
xcodebuild -scheme romm -destination 'generic/platform=iOS Simulator' build | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add romm/romm/Domain/UseCases/Emulator/LaunchEmulatorUseCase.swift romm/rommTests/LaunchEmulatorUseCaseTests.swift
git commit -m "feat: extend LaunchEmulatorUseCase with LaunchDecision"
```

### Task 2.2: Tests für unbrauchbare RomDetailViewModel-Pfade reparieren

**Files:**
- Modify: `romm/romm/UI/RomDetail/RomDetailViewModel.swift` (nur dort, wo die alte `EmulatorLaunchResult` API genutzt wurde)

- [ ] **Step 1: Anstellen, wo `.success` ohne Payload geprüft wurde**

```bash
grep -n "EmulatorLaunchResult\|case \\.success" romm/romm/UI/RomDetail/RomDetailViewModel.swift
```

- [ ] **Step 2: Aufruf anpassen**

Im ViewModel an der Stelle, wo `.success` gematcht wurde:

```swift
switch result {
case .success(let decision):
    self.launchDecision = decision
case .failure(let error):
    self.launchError = error
}
```

Property im ViewModel ergänzen (mit `@Published` oder via `@Observable`, je nach Pattern der Datei):

```swift
var launchDecision: LaunchDecision?
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme romm -destination 'generic/platform=iOS Simulator' build | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/RomDetail/RomDetailViewModel.swift
git commit -m "feat: consume LaunchDecision in RomDetailViewModel"
```

---

## Phase 3 — DeltaCore-Adapter + UI-Integration

Setzt Phase 0 (Spike) erfolgreich voraus. Beachte: Adapter ist die einzige Stelle, die DeltaCore importiert.

### Task 3.1: Dependencies ins Xcode-Projekt aufnehmen

**Erledigt in Phase 0** (Subprojekt-Integration). Falls dieser Punkt noch offen ist, dort weiterarbeiten. Hier nichts zu tun.

### Task 3.2: `DeltaCoreSession`-Adapter

**Files:**
- Create: `romm/romm/UI/Emulator/Delta/DeltaCoreSession.swift`

**Spike-Abhängigkeit:** Diese Signaturen orientieren sich am DeltaCore-Quellcode (z. B. `EmulatorCore`, `GameViewController`, `Game`, `GameType`). Falls Spike-Findings (Task 0.1 Step 9) abweichende Signaturen ergaben, diese hier vor Implementierung anpassen.

- [ ] **Step 1: Implementierung**

```swift
import Foundation
import UIKit
import DeltaCore
import GBADeltaCore

@MainActor
final class DeltaCoreSession {

    private let gameURL: URL
    private let gameType: GameType
    private let saveStore: PSaveStore
    private let romId: Int

    let viewController: GameViewController
    private var emulatorCore: EmulatorCore?

    init(gameURL: URL, gameType: GameType, romId: Int, saveStore: PSaveStore) {
        self.gameURL = gameURL
        self.gameType = gameType
        self.romId = romId
        self.saveStore = saveStore

        let vc = GameViewController()
        let game = Game(fileURL: gameURL, type: gameType)
        vc.game = game
        self.viewController = vc
        self.emulatorCore = vc.emulatorCore
    }

    func start() {
        loadBatteryIfAvailable()
        emulatorCore?.start()
        emulatorCore?.resume()
    }

    func pause() { emulatorCore?.pause() }
    func resume() { emulatorCore?.resume() }

    func stop() {
        flushBattery()
        emulatorCore?.stop()
    }

    func saveState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        core.saveSaveState(to: tmp)
        let data = try Data(contentsOf: tmp)
        try saveStore.writeState(romId: romId, slot: slot, data: data)
        try? FileManager.default.removeItem(at: tmp)
    }

    func loadState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        guard let data = try saveStore.readState(romId: romId, slot: slot) else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        try data.write(to: tmp)
        try core.load(SaveState(fileURL: tmp, gameType: gameType))
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Battery

    private func loadBatteryIfAvailable() {
        guard let data = try? saveStore.readBattery(romId: romId),
              let core = emulatorCore else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("battery-\(UUID().uuidString).sav")
        try? data.write(to: tmp)
        try? core.load(GameSave(fileURL: tmp, gameType: gameType))
    }

    private func flushBattery() {
        guard let core = emulatorCore, let save = core.gameSave else { return }
        if let data = try? Data(contentsOf: save.fileURL) {
            try? saveStore.writeBattery(romId: romId, data: data)
        }
    }
}
```

- [ ] **Step 2: Build prüfen**

```bash
xcodebuild -scheme romm -destination 'generic/platform=iOS Simulator' build | tail -20
```

Bei API-Diskrepanzen (z. B. Methoden anders benannt): jeweilige Stelle anpassen, alle Anpassungen kompakt in einem Commit.

- [ ] **Step 3: Commit**

```bash
git add romm/romm/UI/Emulator/Delta/DeltaCoreSession.swift
git commit -m "feat: add DeltaCoreSession adapter"
```

### Task 3.3: `DeltaEmulatorView` (SwiftUI-Wrapper)

**Files:**
- Create: `romm/romm/UI/Emulator/Delta/DeltaEmulatorView.swift`
- Create: `romm/romm/UI/Emulator/Delta/DeltaEmulatorViewModel.swift`

- [ ] **Step 1: ViewModel**

```swift
import Foundation
import Observation
import DeltaCore

@Observable
@MainActor
final class DeltaEmulatorViewModel {
    let rom: Rom
    let gameType: DeltaGameType
    var errorMessage: String?
    var session: DeltaCoreSession?

    private let localROMRepo: PLocalROMRepository
    private let resolver: PROMFileResolver
    private let saveStore: PSaveStore
    private let logger = Logger.viewModel

    init(
        rom: Rom,
        gameType: DeltaGameType,
        localROMRepo: PLocalROMRepository,
        resolver: PROMFileResolver = ROMFileResolver(),
        saveStore: PSaveStore = LocalSaveStore()
    ) {
        self.rom = rom
        self.gameType = gameType
        self.localROMRepo = localROMRepo
        self.resolver = resolver
        self.saveStore = saveStore
    }

    func bootstrap() {
        do {
            guard let downloaded = localROMRepo.findDownloadedROM(byRomId: rom.id) else {
                errorMessage = "ROM bitte zuerst herunterladen."
                return
            }
            let base = localROMRepo.romsBaseURL()
            let url = try resolver.resolve(rom: downloaded, baseURL: base, gameType: gameType)
            let deltaType = Self.deltaCoreGameType(for: gameType)
            session = DeltaCoreSession(
                gameURL: url, gameType: deltaType,
                romId: rom.id, saveStore: saveStore
            )
            session?.start()
        } catch {
            errorMessage = "Konnte ROM-Datei nicht öffnen: \(error.localizedDescription)"
            logger.error("DeltaCore launch failed: \(error)")
        }
    }

    func teardown() {
        session?.stop()
        session = nil
    }

    private static func deltaCoreGameType(for type: DeltaGameType) -> GameType {
        switch type {
        case .gba: return GBA.gameType
        }
    }
}
```

**Hinweis:** `localROMRepo.findDownloadedROM(byRomId:)` und `localROMRepo.romsBaseURL()` müssen existieren. Falls die `PLocalROMRepository`-Schnittstelle andere Methoden anbietet, vor diesem Step in einem kleinen Vor-Step anpassen (`grep -n "func " romm/romm/Domain/RepositoryProtocols/PLocalROMRepository.swift`).

- [ ] **Step 2: SwiftUI-View**

```swift
import SwiftUI
import DeltaCore

struct DeltaEmulatorView: View {
    @State private var viewModel: DeltaEmulatorViewModel
    @Environment(\.dismiss) private var dismiss

    init(rom: Rom, gameType: DeltaGameType, factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        _viewModel = State(initialValue: DeltaEmulatorViewModel(
            rom: rom, gameType: gameType,
            localROMRepo: factory.localROMRepository
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = viewModel.session {
                DeltaGameViewControllerHost(controller: session.viewController)
                    .ignoresSafeArea()
            }
            if let error = viewModel.errorMessage {
                ErrorOverlay(message: error) { dismiss() }
            }
        }
        .onAppear { viewModel.bootstrap() }
        .onDisappear { viewModel.teardown() }
    }
}

private struct DeltaGameViewControllerHost: UIViewControllerRepresentable {
    let controller: GameViewController
    func makeUIViewController(context: Context) -> GameViewController { controller }
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

private struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundColor(.red)
            Text(message).foregroundColor(.white).multilineTextAlignment(.center)
            Button("Close", action: onDismiss).foregroundColor(.white)
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.9)))
        .padding()
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme romm -destination 'generic/platform=iOS Simulator' build | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/Emulator/Delta/DeltaEmulatorView.swift romm/romm/UI/Emulator/Delta/DeltaEmulatorViewModel.swift
git commit -m "feat: add DeltaEmulatorView and view model"
```

### Task 3.4: `EmulatorRouterView`

**Files:**
- Create: `romm/romm/UI/Emulator/EmulatorRouterView.swift`

- [ ] **Step 1: Implementierung**

```swift
import SwiftUI

struct EmulatorRouterView: View {
    let decision: LaunchDecision

    var body: some View {
        switch decision {
        case .web(let rom):
            EmulatorView(rom: rom)
        case .deltaCore(let rom, let gameType):
            DeltaEmulatorView(rom: rom, gameType: gameType)
        }
    }
}
```

- [ ] **Step 2: Aufrufer `RomDetailView` umstellen**

In `romm/romm/UI/RomDetail/RomDetailView.swift` Zeile 191:

**Vorher:**
```swift
EmulatorView(rom: currentSelectedRom)
```

**Nachher:**
```swift
if let decision = viewModel.launchDecision {
    EmulatorRouterView(decision: decision)
} else {
    EmulatorView(rom: currentSelectedRom) // Rückwärtskompatibel falls Decision noch nicht gesetzt
}
```

Analog `romm/romm/UI/Devices/LocalDevice/PlatformROMs/PlatformROMsListView.swift` Zeile 41 — dort bleibt die direkte `EmulatorView`-Nutzung, weil `PlatformROMsListView` keinen Pre-Flight via UseCase fährt. Optional Folge-Task: dort ebenfalls über UseCase routen (Out of Scope MVP).

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme romm -destination 'generic/platform=iOS Simulator' build | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/Emulator/EmulatorRouterView.swift romm/romm/UI/RomDetail/RomDetailView.swift
git commit -m "feat: route emulator launch via EmulatorRouterView"
```

---

## Phase 4 — Settings + Polish

### Task 4.1: DI für neue Use Cases

**Files:**
- Modify: `romm/romm/UI/DI/DependencyFactory.swift`
- Modify: `romm/romm/UI/DI/MockDependencyFactory.swift`

- [ ] **Step 1: Protokoll erweitern**

Im Protocol `PDependencyFactory` ergänzen:

```swift
var enginePreference: PEmulatorEnginePreference { get }
func makePlatformEngineSupport() -> PPlatformEngineSupport
```

- [ ] **Step 2: Default-Implementierung**

```swift
lazy var enginePreference: PEmulatorEnginePreference = EmulatorEnginePreference()
func makePlatformEngineSupport() -> PPlatformEngineSupport { PlatformEngineSupport() }
```

`makeLaunchEmulatorUseCase` so anpassen, dass die neuen Abhängigkeiten injiziert werden:

```swift
func makeLaunchEmulatorUseCase() -> PLaunchEmulatorUseCase {
    LaunchEmulatorUseCase(
        tokenProvider: TokenProvider(),
        checkEmulatorSupport: makeCheckEmulatorSupportUseCase(),
        enginePreference: enginePreference,
        platformSupport: makePlatformEngineSupport()
    )
}
```

In `MockDependencyFactory` ebenfalls hinzufügen (mit Stubs für Tests/Previews).

- [ ] **Step 3: Build**

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/DI/DependencyFactory.swift romm/romm/UI/DI/MockDependencyFactory.swift
git commit -m "feat: register EnginePreference and PlatformEngineSupport in DI"
```

### Task 4.2: Settings-Picker "Emulator Engine"

**Files:**
- Create: `romm/romm/UI/Settings/EmulatorEngineSettingsView.swift`
- Modify: Settings-Einstiegsview/Menü (Datei via Search ermitteln)

- [ ] **Step 1: View implementieren**

```swift
import SwiftUI

struct EmulatorEngineSettingsView: View {
    @State private var selection: EmulatorEngine
    private let preference: PEmulatorEnginePreference

    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.preference = factory.enginePreference
        _selection = State(initialValue: factory.enginePreference.current)
    }

    var body: some View {
        Form {
            Section(header: Text("Engine")) {
                Picker("Engine", selection: $selection) {
                    Text("Web (EmulatorJS)").tag(EmulatorEngine.web)
                    Text("DeltaCore (Beta)").tag(EmulatorEngine.deltaCore)
                }
                .pickerStyle(.inline)
            }
            Section(footer: Text("DeltaCore startet die Emulation nativ. Aktuell wird nur Game Boy Advance unterstützt; andere Plattformen fallen automatisch auf Web zurück.")) { EmptyView() }
        }
        .navigationTitle("Emulator")
        .onChange(of: selection) { _, new in preference.current = new }
    }
}
```

- [ ] **Step 2: Einstiegsstelle finden**

```bash
grep -rn "ImageCacheSettingsView\|NavigationLink" romm/romm/UI/Settings romm/romm/UI/Profile --include="*.swift" | head -20
```

Im gefundenen Settings-Index-View einen `NavigationLink("Emulator", destination: EmulatorEngineSettingsView())` ergänzen.

- [ ] **Step 3: Build + manueller Test**

App starten, in Settings navigieren, Engine umschalten, Spiel starten → richtige View wird geladen.

- [ ] **Step 4: Commit**

```bash
git add romm/romm/UI/Settings/EmulatorEngineSettingsView.swift <ggf. Settings-Index-View>
git commit -m "feat: add Emulator Engine setting"
```

### Task 4.3: AGPL-Lizenzhinweis

**Files:**
- Create: `romm/romm/UI/Settings/LicensesView.swift` (falls noch nicht vorhanden — sonst erweitern)

- [ ] **Step 1: Hinweis-Sektion**

```swift
import SwiftUI

struct LicensesView: View {
    var body: some View {
        List {
            Section(header: Text("Emulator-Engines")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DeltaCore & GBADeltaCore").font(.headline)
                    Text("© Riley Testut. Lizensiert unter AGPL-3.0. https://github.com/rileytestut/DeltaCore")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Lizenzen")
    }
}
```

- [ ] **Step 2: Aus Settings verlinken**

`NavigationLink("Lizenzen", destination: LicensesView())` in der Settings-Index-View.

- [ ] **Step 3: Commit**

```bash
git add romm/romm/UI/Settings/LicensesView.swift <Settings-Index-View>
git commit -m "docs: add AGPL license disclosure for DeltaCore"
```

### Task 4.4: Lifecycle-Polish (Pause beim Backgrounding)

**Files:**
- Modify: `romm/romm/UI/Emulator/Delta/DeltaEmulatorView.swift`

- [ ] **Step 1: ScenePhase-Hook**

```swift
@Environment(\.scenePhase) private var scenePhase
```

Im `body` ergänzen:

```swift
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active: viewModel.session?.resume()
    case .inactive, .background: viewModel.session?.pause()
    @unknown default: break
    }
}
```

- [ ] **Step 2: Build + manuell testen**

App in Hintergrund schicken, Spielfeld erscheint pausiert; zurück in Vordergrund → läuft weiter.

- [ ] **Step 3: Commit**

```bash
git add romm/romm/UI/Emulator/Delta/DeltaEmulatorView.swift
git commit -m "feat: pause DeltaCore session on background"
```

### Task 4.5: Manueller End-to-End-Smoke-Test

- [ ] **Step 1: Test-Plan abarbeiten**

1. App im Simulator/Device starten.
2. Settings → Emulator → Engine auf "Web (EmulatorJS)". GBA-ROM starten → WebView lädt. ✔
3. Settings → Emulator → Engine auf "DeltaCore (Beta)". GBA-ROM (zuvor heruntergeladene) starten → DeltaCore lädt nativ, Bild + Touch-Skin sichtbar. ✔
4. Im Spiel: Save State erstellen (über GameViewController-Menü, falls aktiv) → App neu starten → State laden. ✔
5. Spiel mit echtem In-Game-Save (z. B. Pokémon-Speicherpunkt) → App neu starten → Battery-Save geladen. ✔
6. Nicht-unterstützte Plattform (z. B. PSX) mit DeltaCore-Engine im Setting → Fallback zur WebView. ✔
7. ROM, die noch NICHT heruntergeladen ist, mit DeltaCore-Engine starten → Fehlerdialog "ROM bitte zuerst herunterladen". ✔

- [ ] **Step 2: Findings in CHANGELOG/Spec ergänzen**

`docs/superpowers/specs/2026-05-15-deltacore-integration-design.md` Abschnitt "Spike Findings" ergänzen um "MVP Verification".

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-15-deltacore-integration-design.md
git commit -m "docs: record MVP verification for DeltaCore integration"
```

---

## Phase 5 — Branch-Abschluss

### Task 5.1: PR vorbereiten

- [ ] **Step 1: Vollständiger Test-Lauf**

```bash
xcodebuild -scheme romm -destination 'platform=iOS Simulator,name=iPhone 15' test | tail -40
```

Erwartet: alle Tests grün.

- [ ] **Step 2: PR erstellen**

```bash
git push -u origin feature/deltacore-integration
gh pr create --title "feat: integrate DeltaCore (GBA) as native emulator engine" --body "$(cat <<'EOF'
## Summary
- DeltaCore + GBADeltaCore (Fork mit SPM) als alternative, native Emulator-Engine.
- Neuer Settings-Picker "Emulator Engine" (Default: Web/EmulatorJS).
- Architektur generisch für weitere Cores ausgelegt; MVP unterstützt GBA.

## Test plan
- [ ] Engine "Web" startet weiterhin EmulatorJS in WebView
- [ ] Engine "DeltaCore" startet GBA-ROM nativ
- [ ] Save State + Battery-Save persistieren lokal
- [ ] Pause beim Backgrounding
- [ ] AGPL-Lizenztext in Settings sichtbar
EOF
)"
```

---

## Spec-Coverage-Check

- `EmulatorEngine` / `EmulatorEnginePreference` → Task 1.1, 1.2
- `PlatformEngineSupport` → Task 1.3
- `SaveStore` + `LocalSaveStore` → Task 1.4, 1.5
- `ROMFileResolver` → Task 1.6
- `PlatformSlugToGameType` → Task 1.7
- `LaunchEmulatorUseCase` + `LaunchDecision` → Task 2.1, 2.2
- SPM-Dependencies (Fork) → Task 0.x, 3.1
- `DeltaCoreSession` → Task 3.2
- `DeltaEmulatorView` → Task 3.3
- `EmulatorRouterView` → Task 3.4
- DI-Registrierung → Task 4.1
- Settings-Picker → Task 4.2
- AGPL-Lizenzhinweis → Task 4.3
- Lifecycle-Polish → Task 4.4
- Manueller MVP-Verify → Task 4.5
