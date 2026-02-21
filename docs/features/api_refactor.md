# API Layer Refactoring

## Ziel
Den OpenAPI-generierten Code aufräumen und auf manuelle Pflege umstellen. Der generierte Code soll analysiert, bereinigt und in eine wartbare Struktur überführt werden.

---

## Phase 1: Analyse-Prompt

Kopiere den folgenden Prompt in eine neue Claude-Session:

```
# OpenAPI Code Analyse - RomM iOS App

## Aufgabe
Analysiere den OpenAPI-generierten Code und identifiziere welche Teile tatsächlich verwendet werden und welche nicht.

## Kontext
- Der generierte Code befindet sich in: `romm/romm/Data/DataSources/API/OpenAPIs/`
- Der Wrapper, der die APIs nutzt: `romm/romm/Data/DataSources/API/RommAPIClient.swift`
- Es gibt 16 API-Klassen, 73 Model-Dateien und diverse Support-Dateien

## Struktur des generierten Codes

### API-Dateien (in OpenAPIs/APIs/)
- AuthAPI.swift
- RomsAPI.swift
- CollectionsAPI.swift
- PlatformsAPI.swift
- StatsAPI.swift
- ScreenshotsAPI.swift
- UsersAPI.swift
- SystemAPI.swift
- TasksAPI.swift
- SavesAPI.swift
- SearchAPI.swift
- FirmwareAPI.swift
- ConfigAPI.swift
- FeedsAPI.swift
- RawAPI.swift
- StatesAPI.swift

### Support-Dateien (in OpenAPIs/)
- APIs.swift (RequestBuilder, rommAPI base class)
- Models.swift (Base protocols & types)
- Configuration.swift
- APIHelper.swift
- CodableHelper.swift
- URLSessionImplementations.swift
- JSONDataEncoding.swift
- JSONEncodingHelper.swift
- Extensions.swift
- Validation.swift
- OpenISO8601DateFormatter.swift
- SynchronizedDictionary.swift

### Model-Dateien (in OpenAPIs/Models/)
73 Model-Dateien (UserSchema, SimpleRomSchema, DetailedRomSchema, etc.)

## Deine Aufgabe

### 1. Analysiere die Verwendung
Durchsuche das gesamte Projekt (außerhalb von OpenAPIs/) nach:
- Imports der API-Klassen
- Aufrufe von API-Methoden
- Verwendung der Model-Typen
- Verwendung der Support-Klassen

### 2. Erstelle zwei Listen

#### Liste A: VERWENDET (behalten)
Alle Dateien und spezifischen Methoden/Typen, die tatsächlich im Projekt verwendet werden.

Format:
```
## API-Klassen
- [ ] AuthAPI.swift
  - [ ] loginWithToken()
  - [ ] logout()
- [ ] RomsAPI.swift
  - [ ] getRomsApiRomsGet()

## Models
- [ ] UserSchema.swift (verwendet in: RommAPIClient.swift:45, UserRepository.swift:12)
- [ ] SimpleRomSchema.swift (verwendet in: ...)

## Support-Dateien
- [ ] APIs.swift (Basis-Infrastruktur, erforderlich)
```

#### Liste B: NICHT VERWENDET (entfernen)
Alle Dateien und Methoden, die nirgends referenziert werden.

Format:
```
## API-Klassen (komplett ungenutzt)
- [ ] FeedsAPI.swift
- [ ] FirmwareAPI.swift

## API-Methoden (teilweise ungenutzt)
- [ ] RomsAPI.swift
  - [ ] updateRomApiRomsPut() - nicht verwendet

## Models (ungenutzt)
- [ ] FirmwareSchema.swift
- [ ] FeedSchema.swift
```

### 3. Abhängigkeitsanalyse
Prüfe für jeden verwendeten Typ, welche anderen Typen er referenziert:
- Welche Models werden von anderen Models als Properties verwendet?
- Welche Support-Dateien sind für die verwendeten APIs zwingend erforderlich?

### 4. Ausgabe
Erstelle einen strukturierten Report mit:
1. **Zusammenfassung**: X von Y API-Klassen verwendet, X von Y Models verwendet
2. **Liste A**: Detaillierte Liste der verwendeten Komponenten mit Referenzen
3. **Liste B**: Liste der zu entfernenden Komponenten
4. **Empfehlungen**: Reihenfolge für das sichere Entfernen

Beginne mit der Analyse!
```

---

## Phase 2: Ergebnis der Analyse

### Zusammenfassung
- API-Klassen: 9/16 verwendet
- Models: 55/73 erforderlich (transitiv über verwendete APIs/Models)
- Support-Dateien: 12/12 erforderlich

Stand der Bereinigung: 2026-02-21 (statische Analyse + direkte Entfernung ungenutzter Dateien)

### Liste A: VERWENDET (behalten)

#### API-Klassen
- [x] AuthAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] RomsAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] CollectionsAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] PlatformsAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] UsersAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] SystemAPI.swift (verwendet in `romm/romm/Data/DataSources/RommAPIClient.swift`)
- [x] StatsAPI.swift (verwendet in `romm/romm/Data/Repositories/StatsRepository.swift`)
- [x] SavesAPI.swift (verwendet in `romm/romm/UI/RomDetail/RomDetailViewModel.swift`)
- [x] StatesAPI.swift (verwendet in `romm/romm/UI/RomDetail/RomDetailViewModel.swift`)

#### Models
- [x] 55 Model-Dateien transitive required (Closure aus direkten Verwendungen + Modellabhängigkeiten)
- [x] Kernmodelle: `DetailedRomSchema`, `SimpleRomSchema`, `CustomLimitOffsetPageSimpleRomSchema`, `UserSchema`, `CollectionSchema`, `PlatformSchema`, `RomUserSchema`, `SaveSchema`, `StateSchema`, `StatsReturn`, `HeartbeatResponse`

#### Support-Dateien
- [x] APIs.swift
- [x] Models.swift
- [x] Configuration.swift
- [x] APIHelper.swift
- [x] CodableHelper.swift
- [x] URLSessionImplementations.swift
- [x] JSONDataEncoding.swift
- [x] JSONEncodingHelper.swift
- [x] Extensions.swift
- [x] Validation.swift
- [x] OpenISO8601DateFormatter.swift
- [x] SynchronizedDictionary.swift

### Liste B: NICHT VERWENDET (entfernen)

#### API-Klassen
- [x] ConfigAPI.swift
- [x] FeedsAPI.swift
- [x] FirmwareAPI.swift
- [x] RawAPI.swift
- [x] ScreenshotsAPI.swift
- [x] SearchAPI.swift
- [x] TasksAPI.swift

#### Models
- [x] AddFirmwareResponse.swift
- [x] ConfigResponse.swift
- [x] HTTPValidationError.swift
- [x] JobStatus.swift
- [x] SearchCoverSchema.swift
- [x] SearchRomSchema.swift
- [x] TaskExecutionResponse.swift
- [x] TaskInfo.swift
- [x] TaskStatusResponse.swift
- [x] TinfoilFeedFileSchema.swift
- [x] TinfoilFeedSchema.swift
- [x] TinfoilFeedTitleDBSchema.swift
- [x] ValidationError.swift
- [x] ValidationErrorLocInner.swift
- [x] WebrcadeFeedCategorySchema.swift
- [x] WebrcadeFeedItemPropsSchema.swift
- [x] WebrcadeFeedItemSchema.swift
- [x] WebrcadeFeedSchema.swift

---

## Phase 3: Bereinigung

### Schritt 1: Ungenutzte Dateien entfernen
- [ ] Backup erstellen
- [x] Ungenutzte API-Klassen löschen
- [x] Ungenutzte Models löschen
- [ ] Build testen

### Schritt 2: Code vereinfachen
- [ ] RequestBuilder-Pattern evaluieren (brauchen wir das noch?)
- [ ] Support-Dateien auf das Minimum reduzieren
- [ ] Unnötige Protokolle entfernen

### Schritt 3: Manuelle Struktur aufbauen
- [ ] Eigene API-Schicht designen
- [ ] Models mit nur benötigten Properties
- [ ] Saubere Error-Handling-Strategie

---

## Notizen

<!-- Weitere Notizen hier -->
