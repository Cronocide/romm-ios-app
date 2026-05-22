# Libretro Cores

Hier landen libretro-Cores als `.dylib` oder `.framework`, die zur App
gelinkt werden. Sie werden zur Laufzeit via `dlopen` aus `LibretroFrontend`
geladen.

## Lookup-Reihenfolge (`LibretroSession.locateCoreDylib`)

1. `Bundle.main/Frameworks/<name>.framework/<name>`
2. `Bundle.main/Frameworks/<name>.dylib`
3. `~/Documents/LibretroCores/<name>.dylib` (manueller Sideload via Files-App,
   nur für lokales Testen brauchbar)

## Aktuell erwartete Dylibs

| Core              | Erwarteter Dateiname              | Plattform |
| ----------------- | --------------------------------- | --------- |
| PCSX ReARMed (PS1)| `pcsx_rearmed_libretro_ios.dylib` | iOS arm64 |

## Bezugsquellen

- Libretro Buildbot: <https://buildbot.libretro.com/nightly/apple/ios-arm64/latest/>
- Provenance baut eigene Dylibs in `CoresRetro/RetroArch/` – die können wir
  perspektivisch wiederverwenden, sind aber auf `PVThinLibretroFrontend`
  angepasst (Code-Signing, Embedded-Frameworks-Layout).

## BIOS

PS1 braucht `scph5500.bin`, `scph5501.bin`, `scph5502.bin` in
`~/Documents/LibretroSystem/`. Das Verzeichnis wird beim ersten Start
automatisch angelegt; BIOS-Dateien selbst nicht eingecheckt.

## Embedding ins Xcode-Projekt

1. Dylib oder XCFramework nach `Vendor/Libretro/` legen.
2. In Xcode unter Target `romm` → General → Frameworks, Libraries, and
   Embedded Content hinzufügen.
3. Embed-Modus: **Embed & Sign**.

Solange das nicht passiert, fällt der Lookup auf den Documents-Pfad zurück
und zeigt einen Fehler in der UI, wenn dort nichts liegt.
