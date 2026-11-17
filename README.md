# Birding Companion — Phase 1

Native iPhone SwiftUI prototype. Open `BirdingCompanion.xcodeproj` and select the shared **BirdingCompanion** scheme. The app starts on **Ontdek**, with current-location heading and icon filters. Use **Bekijk voorbeeldpagina** to inspect the six-species demonstration. Live 30-day frequency data is not yet connected; see `Docs/DISCOVER.md`.

## Prerequisites and first Mac setup

1. Install Xcode 16 or newer with Swift 6 and an iOS simulator runtime. Confirm the actual Mac/iPhone versions before finalizing support. **iOS 17.0 is a provisional project setting, not an approved deployment decision.**
2. Open the project. No third-party runtime packages, credentials or custom entitlements are needed; licensed fonts are bundled. Choose an available iPhone simulator.
3. Run Product → Build, then Product → Test. Resolve any compiler/SDK issues before treating this as build verified.
4. Launch and check the hero composition, tabs, back navigation and bottom navigation. At 320/375-point widths and accessibility text sizes, confirm wrapping, horizontal tab scrolling, 44-point actions and VoiceOver order.
5. Add an observation with +. Relaunch the app, check history and lifelist, edit date/time/location, and relaunch again. Uncertain and captive records must not count by default.
6. Export JSON in history; inspect it in Files. Try offline logging, empty history, Google search online/offline, closing Safari, and the unavailable audio message.
7. For a physical device, choose a unique bundle identifier and your signing team. No microphone/photo permissions are requested. Foreground location permission is requested when opening Ontdek or adding an observation.

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

Species IDs/taxonomy remain mock-only. No production taxonomy authority was chosen. Generated artwork requires independent anatomical review. True local 30-day report counts and licensed range polygons are still external-data dependencies. Recognition, targets, global catalog, sync, import, deletion and production migrations remain later-phase work. New logs require a map point and editable place name; country is derived automatically when available. Do not use this prototype as the sole repository of valuable records.
