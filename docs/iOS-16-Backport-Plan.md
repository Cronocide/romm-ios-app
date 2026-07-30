# iOS 16 Backport Plan

Retarget the app from `IPHONEOS_DEPLOYMENT_TARGET = 18.6` to **16.0**, widening support from
iPhone XS-era-and-newer to everything iOS 16 runs on.

**Verdict: feasible.** No dependency blocks it. The work is almost entirely in this
repository's own Swift code, and the largest piece — migrating off the iOS 17 Observation
framework — is mechanical but wide.

---

## 1. The binding constraint: there is no Mac

Every decision below follows from this. GitHub Actions is the only available compiler, so:

- **CI is the inner loop, not a gate.** `.github/workflows/ci.yml` runs on every push to
  `main` and exists to produce readable compiler errors fast. It cancels superseded runs,
  caches DerivedData, and writes an aggregated error digest to the job summary.
- **The digest is tailored to this initiative.** It greps availability failures
  (`'x' is only available in iOS 17.0 or newer`), groups them by API, and counts them —
  so one CI run replaces a lot of guesswork about what actually breaks.
- **`deployment_target` is a workflow input.** You can compile at 16.0 *without committing
  the change*, via **Actions → CI → Run workflow → deployment_target: 16.0**. The override
  applies to every target including the vendored cores. Use this to get the true error
  surface before touching a single file.
- **Builds target a device destination, unsigned.** `Vendor/Libretro/pcsx_rearmed_libretro_ios.framework`
  is a thin arm64 iOS binary with no simulator slice, so a simulator build cannot link.
- **Therefore the test suite cannot run in CI.** `rommTests` and `rommUITests` need a
  simulator, and the app links a device-only framework. This backport has **no automated
  test signal** — see §7.
- **Runtime verification is manual.** The unsigned IPA from `release.yml` sideloads onto a
  real iOS 16 device via AltStore/SideStore. That is the only way to catch the silent
  regressions in §6.

---

## 2. Verified dependency floors

All checked at the SHAs this project actually pins, against the completed submodule checkout.

| Dependency | Floor | Notes |
|---|---|---|
| DeltaCore | **14.0** | `Package.swift .v14`, podspec 14.0. Highest gated call is `API_AVAILABLE(ios(16))`, properly guarded. |
| GBA / GBC / NES / SNES / MelonDS / N64 DeltaCore | **14.0** | No iOS 17 API usage in any wrapper. |
| GPGXDeltaCore | **14.0** | Carries a vestigial project-level `26.0`, but both native targets override to 14.0. |
| Kingfisher 8.5.0 | 13.0 | No change needed. |
| `mft.xcframework` | 13.5 | Prebuilt arm64, `LC_BUILD_VERSION minos=13.5`. |
| `pcsx_rearmed_libretro_ios` | 12.2 | Prebuilt arm64, device-only. |
| **SWCompression 4.9.1** | **17.0** | ❌ Must downgrade — see below. |
| **BitByteData 2.1.0** | **17.0** | ❌ Must be pinned — see below. |

Nested submodules (gambatte, Genesis-Plus-GX, melonDS, mupen64plus, GLideN64, libpng,
snes9x, visualboyadvance-m) are pure C/C++ and carry no iOS API floor.

### The SPM trap

Downgrading SWCompression alone is **not sufficient**. SWCompression 4.8.6 declares its
dependency as `BitByteData from: "2.0.0"`, which is up-to-next-major, so SPM will happily
resolve BitByteData back up to **2.1.0** — reintroducing the iOS 17 floor through the back door.

Both must be constrained:

- `SWCompression` → `upToNextMinorVersion`, `minimumVersion = 4.8.6` (allows 4.8.x only)
- `BitByteData` → add as an **explicit root package reference**, `upToNextMinorVersion`,
  `minimumVersion = 2.0.4`. A root constraint overrides the transitive `from:`.

Side effect: 4.8.6 still declares a `SwiftCLI` dependency that 4.9.1 dropped, so SwiftCLI
enters `Package.resolved`. It declares no platforms, so it imposes no floor — harmless noise.

Risk is low: the app touches SWCompression in exactly one place —
`Domain/UseCases/Emulator/ROMFileResolver.swift:178`, `SevenZipContainer.open(container:)` —
and that declaration is byte-identical between 4.8.6 and 4.9.1.

**Fallback if 4.8.6 misbehaves:** fork both packages and lower the `platforms:` declaration.
They are pure-Swift compression libraries with no iOS 17 API usage; the `.iOS(.v17)` line is
arbitrary. This keeps current code at the cost of two forks to maintain.

---

## 3. Work breakdown

Ordered so that each step is verifiable by CI before the next begins.

| # | Step | Size | Risk |
|---|---|---|---|
| 1 | Land `ci.yml`, confirm green at current settings | — | none |
| 2 | Dispatch CI with `deployment_target: 16.0`, capture the real error list | — | none |
| 3 | SPM: downgrade SWCompression, pin BitByteData | 2 files | low |
| 4 | `IPHONEOS_DEPLOYMENT_TARGET` 18.6 → 16.0 (6 configurations) | 1 file | low |
| 5 | Migrate 25 `@Observable` classes → `ObservableObject` | 25 files, 185 properties | **high** |
| 6 | Update 29 view ownership call sites | ~24 files | medium |
| 7 | Replace 15 two-param `onChange` call sites, remove `@Bindable` | 11 files | low |
| 8 | Rewrite `MainActor.assumeIsolated` (5 sites) | 1 file | **high** |
| 9 | Replace the iOS 18 `Tab {}` builder | 1 file | low |
| 10 | Replace `.navigationDestination(item:)` | 1 file | low |
| 11 | Fix the silent regressions in §6 | 2 files | medium |

Step 1 must be green **before** anything else lands, so that later failures are attributable.

### Steps 8–10: the blockers a SwiftUI-shaped search misses

These three were not in my original estimate. A systematic sweep found them; they are worth
calling out because two of them sit outside the "SwiftUI view model" mental model.

**`MainActor.assumeIsolated` — iOS 17.0 — 5 sites, all in
`UI/Emulator/Libretro/LibretroFrontend+Environment.swift` (lines 9, 13, 29, 37, 47).**
This is a *concurrency* API, not a SwiftUI one, so nothing about the Observation migration
surfaces it. These are synchronous trampolines invoked from libretro's C callbacks on the
emulator core thread. `assumeIsolated` asserts main-actor isolation and traps if violated;
any replacement changes that safety property. Options: hop via `DispatchQueue.main.sync`
(deadlock risk if already on main), or mark the accessed statics `nonisolated(unsafe)` — which
neighbouring code in the same file already does — and drop the assertion. **Treat this as the
highest-risk non-Observation change**: it is five lines, but it governs threading in the
emulator hot path, and a wrong choice produces a deadlock or a data race rather than a
compile error.

**iOS 18 `Tab {}` builder — `UI/App/MainTabView.swift` lines 20, 26, 32, 38, 44.**
Note this is **iOS 18**, not 17 — the app's tab bar cannot compile even at an iOS 17 floor.
Convert to the classic `TabView { View().tabItem { Label(...) }.tag(...) }` form. Line 44 also
uses `role: .search` (`TabRole`, iOS 18), which has no iOS 16 equivalent; the Search tab
becomes an ordinary tab. Cosmetic loss only.

**`.navigationDestination(item:)` — iOS 17.0 —
`UI/Devices/LocalDevice/PlatformROMs/PlatformROMsListView.swift:69`.** The `isPresented:`
overload is iOS 16.0; only the `item:` overload is 17.0. Single-line rewrite.

**Corrected `onChange` count:** 15 call sites across 11 files, not ~11. Only **one** actually
reads the old value, so 14 collapse to the `{ newValue in }` form mechanically and one needs
thought.

**Four files use `@Observable` without `import Observation`**, relying on SwiftUI's re-export:
`Data/Services/ConnectionLogger.swift`, `UI/Search/SearchViewModel.swift`,
`UI/Devices/SFTP/SFTPDirectoryBrowserViewModel.swift`,
`UI/Devices/SFTP/AddEditSFTPDeviceViewModel.swift`. Driving the migration off
`import Observation` would miss all four.

---

## 4. The Observation migration (step 5)

25 `@Observable` classes, 185 mutable stored properties, 33 computed properties.
All are classes; 24 of 25 are `@MainActor`. No `@ObservationIgnored` anywhere, no nested
`@Observable` properties, no `lazy var`, no property wrappers inside the class bodies, and
extensions contain methods only. Mechanically, nothing obstructs `@Published`.

### The rule that matters

> Annotate **every mutable stored `var` with `@Published`** — including `private` ones.

This is the crux. `@Observable` tracks reads at property granularity, so a computed property
that reads a private var updates automatically. `ObservableObject` does not: it fires a single
`objectWillChange` when a `@Published` property changes, and the view re-reads everything.

So a computed property backed by an **unpublished private var silently stops updating** —
it only refreshes if some *other* published property happens to change at the same moment.
28 of the 33 computed properties derive from mutable state, and four read private vars
exclusively:

| Type | Computed property | Reads | Breaks |
|---|---|---|---|
| `PlatformDetailViewModel` | `canLoadMore` | private `hasMoreRoms` | infinite scroll freezes |
| `SFTPDirectoryBrowserViewModel` | `canGoBack` | private `pathHistory` | back button stalls |
| `AddEditSFTPDeviceViewModel` | `isEditing` | private `editingConnection` | form title/mode wrong |
| `CollectionsViewModel` | `viewState` | private `hasLoadedOnce` | whole screen state machine |

Publishing the private backing var fixes all four. `@Published private var` is legal.

The same trick resolves the one property that looks unmigratable: `SFTPUploadViewModel.error`
is a custom `get`/`set` computed property over a private `_error`. Publish `_error` and the
computed `error` re-reads correctly — no hand-rolled `objectWillChange.send()` needed.

**Do not publish** pure bookkeeping that no view or computed property reads — `Task` handles
(`loadTask`, `searchTask`, `runningTasks`) and `Set<AnyCancellable>`. Publishing those is
harmless but adds spurious re-renders.

### Highest-risk types, in order

1. **`SFTPUploadViewModel`** (838 lines) — 24 mutable stored properties, 6 computed, the
   `_error` indirection, and four chained computed properties driving live upload UI.
2. **`PlatformDetailViewModel`** — pagination gate reads a private var.
3. **`SFTPDirectoryBrowserViewModel`** — 5 computed properties; `goBack()` mutates
   `pathHistory` before `currentPath`.
4. **`AddEditSFTPDeviceViewModel`** — 14 `TextField`-bound vars plus 3 computed validators.
   Live form validation is precisely where `@Published`-vs-computed diverges.
5. **`ProfileViewModel`** — its single stored property carries a `didSet` that persists the
   setting. `@Published` + `didSet` compiles, but `objectWillChange` fires *before* `didSet`,
   and the property is assigned in `init` where `didSet` does not fire. Preserve both.

---

## 5. View ownership changes (step 6)

29 sites. The mapping is mostly mechanical, with five traps:

- **`State(initialValue:)` has no `StateObject` equivalent.** Three sites
  (`EmulatorView.swift:21`, `SFTPUploadView.swift:18`, `ShareSwipeButton.swift:7`) must become
  `StateObject(wrappedValue:)`. A token rename produces a compile error.
- **`@SwiftUI.State` module-qualified** at `NativeEmulatorView.swift:5` and
  `LibretroEmulatorView.swift:5` — a plain `@State` regex misses both. Their sibling
  `@SwiftUI.State` properties for `Bool`/`Int`/`String` must *stay* `@State`.
- **`EmulatorView.swift:273`** holds the VM inside a `Coordinator: NSObject` class. It must
  remain a plain `let`. A blanket "`let vm: EmulatorViewModel` → `@ObservedObject`" rule breaks it.
- **`SyncSaveSheet.swift:22`** is a non-private `@State var` set through the memberwise
  initializer by its caller. `@StateObject` cannot be assigned that way. Either accept
  `@ObservedObject` (matching today's actual behaviour — the VM is already rebuilt on every
  sheet body evaluation) or write an explicit `init` using `StateObject(wrappedValue:)`.
- **`SettingsView.swift:29`** declares `@Bindable` as a **local variable inside `body`**, not a
  property, so `@ObservedObject` cannot replace it. Delete the line and rebind line 109 to
  `$profileViewModel` once that becomes `@StateObject`.

Good news: **zero** `@Environment(SomeType.self)` and **zero** `.environment(object)` sites —
the app already uses `@EnvironmentObject`/`.environmentObject` throughout. That removes an
entire category of migration.

---

## 6. Silent regressions — will compile, will misbehave

These produce no compiler error and no CI signal. They are the reason manual device testing
is mandatory.

1. **`ConnectionLogger`** is `@Observable` but is not held by any property wrapper.
   `SetupView.swift:37` reads it through a computed bridge (`private var connectionLogger:
   ConnectionLogger { .shared }`). Under `ObservableObject` that read no longer subscribes,
   so the connection log stops updating live. Needs a real `@StateObject`/`@ObservedObject`
   stored property.
2. **`SFTPDevicesViewModel`** is the only class **not** `@MainActor`, and it mutates
   `connections` from `Task.detached` and non-isolated `async` functions. Once those
   properties are `@Published`, that becomes "Publishing changes from background threads is
   not allowed" — purple runtime warnings, and potentially crashes. It also has a `deinit`
   calling an instance method. Annotating the class `@MainActor` is the likely fix, but it
   will cascade into its call sites.
3. **`AppViewModel.appData`** is a nested `AppData` (already an `ObservableObject` with 6
   `@Published`). Nested observation does not propagate through an outer `ObservableObject`,
   so any view reading `appViewModel.appData.x` directly will not update. Views must consume
   `AppData` as `@EnvironmentObject` — which the 5 existing sites already do. Verify no new
   path reads it transitively.

---

## 7. What this plan cannot verify

Stated plainly, because the gaps are structural rather than oversights:

- **No automated test execution.** The device-only libretro framework rules out simulator
  builds, so `rommTests`/`rommUITests` cannot run in CI. The entire backport has compile-time
  verification only. Making tests runnable would mean excluding the libretro framework from a
  simulator build configuration — worth doing eventually, out of scope here.
- **No runtime verification without a device.** Every issue in §6 is invisible to the compiler.
- **The API inventory is search-derived, not compiler-derived.** Step 2 exists precisely to
  replace it with ground truth. A systematic sweep did clear a long list of candidates —
  Charts, SwiftData, String Catalogs, custom macros, symbol effects, sensory feedback, all
  scroll-target and scroll-geometry APIs, `ContentUnavailableView`, `MeshGradient`, `@Entry`,
  `@Previewable`, and the iOS 17 UIKit trait APIs are **entirely absent** from this codebase —
  but absence of a grep hit is not proof. My own first pass missed three hard blockers,
  including an iOS 18 one; assume the compiler will find more.
- **DerivedData caching may not help.** Xcode invalidates aggressively; cold builds of the
  C/C++ cores are slow. Treat the cache as a bonus, not a guarantee.

---

## 8. Why 16.0 rather than 16.6

Nothing found requires 16.1–16.6, and 16.0 maximises device reach. DeltaCore's gated
`API_AVAILABLE(ios(16))` call is satisfied at 16.0. If step 2 surfaces something that needs a
higher minor, 16.4 is the next sensible stop.

Be aware there is **no headroom** at 16.0. These are used and are *exactly* 16.0:
`NavigationStack` (19 sites), `.toolbarBackground` (8), `.toolbar(.hidden, for: .tabBar)` (3),
`.presentationDetents`, `.scrollDismissesKeyboard`, `Grid` (4), `UnevenRoundedRectangle`,
`ImageRenderer`, `TextField(_:text:axis:)`, and `Task.sleep(for:)`. Dropping below 16 later
would be a substantially larger project than this one.

## 9. Things to deliberately leave alone

- **`#Preview` × 29 sites.** The macro self-gates its expansion with `@available(iOS 17.0, *)`,
  so it compiles cleanly at a 16.0 deployment target. Do not convert these to
  `PreviewProvider`. (Previews that construct view models still need the step-5/6 edits.)
- **`if #available(iOS 16.4, *)` at `UI/Emulator/EmulatorView.swift:219`** (guarding
  `webView.isInspectable`). Redundant today at 18.6; genuinely load-bearing once the floor is
  16.0. Keep it.
- **`if #available(iOS 16.0, *)` at `UI/App/Orientation/OrientationLock.swift:57`.** Becomes a
  no-op at the new floor but is harmless.
- **Test targets.** They use Swift Testing (`import Testing`, 34 `@Test`), which is iOS 16.0+,
  so the suite survives the backport unchanged — it just cannot be *run* in CI (§1).
