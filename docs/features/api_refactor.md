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

<!-- Hier die Ergebnisse der Analyse einfügen -->

### Zusammenfassung
- API-Klassen: ?/16 verwendet
- Models: ?/73 verwendet
- Support-Dateien: ?/12 erforderlich

### Liste A: VERWENDET (behalten)

#### API-Klassen
<!-- Ergebnisse hier -->

#### Models
<!-- Ergebnisse hier -->

#### Support-Dateien
<!-- Ergebnisse hier -->

### Liste B: NICHT VERWENDET (entfernen)

#### API-Klassen
<!-- Ergebnisse hier -->

#### Models
<!-- Ergebnisse hier -->

---

## Phase 3: Bereinigung

### Schritt 1: Ungenutzte Dateien entfernen
- [ ] Backup erstellen
- [ ] Ungenutzte API-Klassen löschen
- [ ] Ungenutzte Models löschen
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
