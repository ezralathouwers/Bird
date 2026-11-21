# Birding Companion — Phase 1

Native iPhone SwiftUI prototype. Open `BirdingCompanion.xcodeproj` and select the shared **BirdingCompanion** scheme. The app starts on **Ontdek**, with current-location heading and icon filters. Use **Bekijk voorbeeldpagina** to inspect the six-species demonstration. Live 30-day frequency data is not yet connected; see `Docs/DISCOVER.md`.

## Prerequisites and first Mac setup

1. Install Xcode 16 or newer with Swift 6 and an iOS simulator runtime. Confirm the actual Mac/iPhone versions before finalizing support. **iOS 17.0 is a provisional project setting, not an approved deployment decision.**
2. Open the project. Resolve the pinned MIT-licensed ZIPFoundation package. No credentials or custom entitlements are needed; licensed fonts and catalog data are bundled. Choose an available iPhone simulator.
3. Run Product → Build, then Product → Test. Resolve any compiler/SDK issues before treating this as build verified.
4. Launch and check the hero composition, tabs, back navigation and bottom navigation. At 320/375-point widths and accessibility text sizes, confirm wrapping, horizontal tab scrolling, 44-point actions and VoiceOver order.
5. Add an observation with +. Relaunch the app, check history and lifelist, edit date/time/location, and relaunch again. Uncertain and captive records must not count by default.
6. Export JSON in history; inspect it in Files. Try offline logging, empty history, Google search online/offline, closing Safari, and the unavailable audio message.
7. For a physical device, choose a unique bundle identifier and your signing team. Microphone permission is requested for Sound ID; camera permission only when taking a photo. Foreground location permission is requested when opening Ontdek or adding an observation.

Debug builds use **Build Active Architecture Only = Yes** at project level,
inherited by the app and tests. Release retains **No**. This keeps the Debug
simulator architecture aligned with Swift package builds on either Apple Silicon
or Intel, without hardcoding an architecture or excluding simulator support.
If an older ZIP download reports an incompatible arm64 ZIPFoundation module while
the app is compiling x86_64, select the blue project → PROJECT BirdingCompanion →
Build Settings → All, search `Build Active Architecture Only`, set Debug to Yes,
clean the build folder and rebuild for the selected iPhone simulator.

Core ML prediction uses a private synchronous helper on each service actor.
This selects the synchronous overload and keeps the non-Sendable model and
feature providers inside that actor; awaiting Core ML's concurrent prediction
overload produced a Swift 6 data-race diagnostic with Xcode 27.2. BioCLIP model
compilation still uses `await` because its URL result can cross the boundary.
Cancellation is checked after prediction/compilation; temporary compiled-model
cleanup is registered before checking cancellation. No unchecked Sendable
conformance or weaker concurrency setting is used. Native rebuilding remains
required: Linux syntax checks do not verify SDK types or model execution.

Terminal equivalents (replace the destination with one listed on your Mac):

```sh
xcodebuild -list -project BirdingCompanion.xcodeproj
xcodebuild -showdestinations -scheme BirdingCompanion -project BirdingCompanion.xcodeproj
xcodebuild test -project BirdingCompanion.xcodeproj -scheme BirdingCompanion -destination 'platform=iOS Simulator,name=<available iPhone>'
```

## Implemented

- Feature folders, app/test targets and shared Xcode scheme; no project generator required.
- Ivory/neutral-grey/taupe tokens, bundled Fraunces for Dutch species titles and DM Sans for other app text.
- Three species tabs, paged artwork with working dots, full-height distribution/observation maps, species history and derived logged-status eyes. Six generated primary illustrations form a pilot; secondary views remain labelled placeholders.
- Dismissible Safari Google Images query using the scientific name; browser-managed loading/failure handling and external browser fallback. No scraping or cached image search; network is required.
- Honest unavailable audio state; local creation/editing, confirmed/captive rules, history, derived lifelist and JSON export.
- Atomic JSON persistence with failed-write rollback and protection against overwriting unreadable/duplicate-ID input.
- XCTest methods covering search, save/reload/edit/export, lifelist rules, invalid records, corruption protection and failed writes.

## Deliberate limitations

Native compilation, test execution, previews, simulator, signing and device behavior **have not been verified** in this Linux environment. See `Docs/VERIFICATION.md`.

The uploaded screenshot is a visual reference, not bundled artwork. Supply the original four bird illustrations, with rights/provenance, for an asset catalog; don't embed or crop the UI screenshot as the functioning screen. Colors are provisional, not claimed as sampled. Fraunces and DM Sans are bundled with their OFL notices. The English name and active tab intentionally use sans-serif according to the brief, even though the screenshot uses serif.

The world guide follows the pinned AviList v2026 checklist, with BirdNET names/mappings and retained original sample IDs; it is not an automatic migration of saved records. Generated artwork requires independent anatomical review. True local 30-day report counts and licensed range polygons are still external-data dependencies. Photo recognition, catalog content enrichment, sync, import, general deletion and production migrations remain later-phase work. New logs require a map point and editable place name; country is derived automatically when available. Do not use this prototype as the sole repository of valuable records.


Sessies: voltooide sessies toevoegen, live vogels loggen met GPS per waarneming, hervatten na herstart en gekoppelde individuele waarnemingen. Zie `Docs/SESSIONS.md` voor opslagmigratie en de nog uit te voeren Xcode-/GPS-controles.


Landen toont unieke gelogde soorten per land met een gefilterd logboek. Doelstellingen bewaart checklists die automatisch afvinken op basis van alle logs. Zie `Docs/COUNTRIES_AND_GOALS.md` voor navigatie, archiefmigratie en Xcode-controles.


Identificatie heeft nu foto-/geluidkeuze, camera/fotokiezer en automatische lokale audio-opname met compact echt sonogram. Fotoherkenning is nog niet aangesloten; zie `Docs/IDENTIFICATION.md` voor modelintegratie en verplichte iPhone-tests.


Geluid-ID is nu in code gekoppeld aan BirdNET+ 3.0.1 Core ML: eenmalige modeldownload (~157 MB), daarna offline herkenning met overlappende audiovensters, highlights en vastgezette resultaten. Gewichten worden niet via Git meegeleverd. Zie `Docs/BIRDNET_INTEGRATION.md`; native build, modeluitvoering en iPhone-prestaties zijn nog niet geverifieerd. Fotoherkenning blijft niet aangesloten.


De wereldgids bevat nu alle 11.172 AviList-v2026-soorten, inclusief soorten zonder Sound ID, plus één apart bewaarde BirdNET-compatibiliteitsvermelding. Zoeken en alle vogelkeuzes gebruiken die lijst. Iedere soort heeft een basispagina; ontbrekende illustraties/feiten blijven placeholders. Zie `Docs/WORLD_SPECIES_PAGES.md` en de inhoudsinventaris voor de verdere uitwerking.
