# Birding Companion — Phase 1

Native iPhone SwiftUI prototype. Open `BirdingCompanion.xcodeproj` and select the shared **BirdingCompanion** scheme. The app starts on the kingfisher detail page; Back returns to the one-species guide.

## Prerequisites and first Mac setup

1. Install Xcode 16 or newer with Swift 6 and an iOS simulator runtime. Confirm the actual Mac/iPhone versions before finalizing support. **iOS 17.0 is a provisional project setting, not an approved deployment decision.**
2. Open the project. No third-party packages, fonts, credentials or entitlements are needed. Choose an available iPhone simulator.
3. Run Product → Build, then Product → Test. Resolve any compiler/SDK issues before treating this as build verified.
4. Launch and check the hero composition, tabs, back navigation and bottom navigation. At 320/375-point widths and accessibility text sizes, confirm wrapping, horizontal tab scrolling, 44-point actions and VoiceOver order.
5. Add an observation with +. Relaunch the app, check history and lifelist, edit count/date/notes, and relaunch again. Uncertain and captive records must not count by default.
6. Export JSON in history; inspect it in Files. Try offline logging, empty history, Google search online/offline, closing Safari, and the unavailable audio message.
7. For a physical device, choose a unique bundle identifier and your signing team. No microphone, photo or location permissions are requested in Phase 1.

Terminal equivalents (replace the destination with one listed on your Mac):

```sh
xcodebuild -list -project BirdingCompanion.xcodeproj
xcodebuild -showdestinations -scheme BirdingCompanion -project BirdingCompanion.xcodeproj
xcodebuild test -project BirdingCompanion.xcodeproj -scheme BirdingCompanion -destination 'platform=iOS Simulator,name=<available iPhone>'
```

## Implemented

- Feature folders, app/test targets and shared Xcode scheme; no project generator required.
- Provisional ivory/charcoal/taupe tokens, system serif exclusively for Dutch species title, system sans-serif elsewhere.
- One large and three small explicitly temporary artwork panels arranged from the supplied design. Five working content tabs, accessible facts, no inert page dots.
- Dismissible Safari Google Images query using the scientific name; browser-managed loading/failure handling and external browser fallback. No scraping or cached image search; network is required.
- Honest unavailable audio state; local creation/editing, confirmed/captive rules, history, derived lifelist and JSON export.
- Atomic JSON persistence with failed-write rollback and protection against overwriting unreadable/duplicate-ID input.
- Six XCTest methods covering search, save/reload/edit/export, lifelist rules, invalid records, corruption protection and failed writes.

## Deliberate limitations

Native compilation, test execution, previews, simulator, signing and device behavior **have not been verified** in this Linux environment. See `Docs/VERIFICATION.md`.

The uploaded screenshot is a visual reference, not bundled artwork. Supply the original four bird illustrations, with rights/provenance, for an asset catalog; don't embed or crop the UI screenshot as the functioning screen. Colors are provisional, not claimed as sampled. The system serif approximates the requested character until a font is approved. The English name and active tab intentionally use sans-serif according to the brief, even though the screenshot uses serif.

Species ID and taxonomy version are explicitly mock-only; no production taxonomy authority was chosen. Facts reproduce brief examples and await independent scientific validation. Maps, recognition, targets, global catalog, sync, import, deletion and production migrations remain later-phase work. Location is an optional text field; GPS and evidence attachments are deferred. Do not use this prototype as the sole repository of valuable records.
