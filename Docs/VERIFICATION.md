# Verification — 16 November 2026

Environment: Linux, Python 3.12.14. `command -v swift` and `command -v xcodebuild` returned no executable. No iOS build or XCTest execution took place.

Executed:

- `git diff --check`: passed (no whitespace errors).
- `python3 -m pip install --quiet --target /workspace/work/validation-deps openstep-parser`: installed a validation-only parser outside the repository; not an application dependency.
- Python `OpenStepDecoder.ParseFromFile` on `project.pbxproj`: passed; 46 project objects and two native targets parsed.
- Python validation of project references, source membership and shared-scheme XML: passed. All 11 Swift files exist, belong to the project and the scheme references existing targets.
- `rg -n 'design: .serif|IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION' BirdingCompanion BirdingCompanion.xcodeproj`: confirmed one explicit serif style, provisional iOS 17 and Swift 6 project settings. This is source inspection, not rendered UI verification.

Six XCTest methods are supplied, not executed. Syntax parsing of the project does not prove Swift compilation, Xcode acceptance or correct runtime behavior. README contains the ordered Mac checklist for compilation, tests, accessibility, persistence and Safari offline behavior.

Outstanding: original artwork and license metadata; screenshot file for color sampling; font choice; independent species-fact review; deployment support confirmation. The uploaded visual was inspected in chat but cannot be claimed as a locally saved or sampled asset.

### Design revision

`git diff --check` passed after the requested design revisions. Font metadata was inspected using fontTools; both original variable fonts and OFL notices are present. Python plist/OpenStep checks validated UIAppFonts, actual bundled resource files, and app resource memberships. These checks do not establish that iOS registered the custom fonts or rendered the carousel correctly. Native compilation remains unverified.

### Footer refinement

`git diff --check` passed. Python OpenStep resource-membership validation, asset-catalog JSON parsing and Pillow PNG integrity validation passed. UI tests were not run; verify 80% icon sizing, 50%-opacity icon appearance, tab targets and no footer/tab-bar gap or overlap on short screens in Xcode. Habitat line can wrap at large Dynamic Type sizes.

### Bottom navigation and Fraunces revision

`git diff --check` passed. OpenStep parsing and resource-existence assertions passed after font replacement; fontTools confirmed Fraunces-9ptBlack and DMSans-9ptRegular PostScript metadata and plist registration paths. Xcode is still unavailable. Verify root bottom inset/home indicator and habitat adjacency in portrait, landscape and small devices, equal-width navigation slots and plus centering, regular variable-font rendering, and title/button top alignment. Verify that every main destination opens, plus saves to history, and detail tabs retain identical font size across selection states.

### Header and text refinement

`git diff --check` passed. Source checks confirm English-before-Dutch heading order, toolbar-based action placement, Logboek copy and ultra-light navigation symbols. This is a reversible UI-only change; no new logic tests were added. Native compilation remains unverified. Test toolbar fit on 320-point screens, back navigation, VoiceOver order and long Dutch names at accessibility text sizes in Xcode.

### Raised observation button

`git diff --check` and source assertions passed: 72-point diameter is 1.5×48, 45-point glyph is 1.5×30, overlap is 0.30×72 = 21.6 points; Logboek uses bird, both toolbar groups shift down 4 points. No new logic tests for this UI-only change. In Xcode verify bottom inset layout, habitat overlap, top portion of circle hit testing, 320-point navigation spacing, and toolbar touch targets. No native build was run.

### Neutral grey and navigation typography

`git diff --check` passed. Source assertions verify neutral colour channel values, 0.8-point plus strokes, uppercase/tracking and a solid circle without a border. No iOS compilation or rendered UI test was possible. Check fine-line visibility, long IDENTIFICEER caption wrapping and contrast on device.

### Icon-only navigation

`git diff --check` and source assertions passed for 24-point destination symbols, ±6-point offsets, removed caption text and explicit accessibility labels. Native layout, VoiceOver focus and target separation still require Xcode/device checks.

### Dark navigation surface

`git diff --check` and source assertions passed for shared selectedBeige button fill, dark navigation surface and light destination icons. Native contrast, home-indicator appearance and safe-area rendering remain unverified without Xcode.

### Interactive distribution tab

`git diff --check` passed. Python OpenStep parsing confirmed the new map file's app source membership and valid project references. Added three XCTest methods for polygon/provenance decoding, rejection of missing-license/empty data, and explicit missing-file behavior. These tests were **not executed** because Swift/Xcode are unavailable. Native MapKit initialization, full-height layout, map interactions, connectivity reporting and GeoJSON rendering require Mac verification. Scientific range display remains pending a licensed, validated dataset.

### Species history tab

`git diff --check` and source assertions passed for compact non-overview layout, scrollable lazy history, species filtering and date/location rows. Added XCTest covering mixed-species filtering, newest-first ordering, retained uncertain records and empty results. XCTest remains unexecuted without Xcode. Verify fixed tabs while history scrolls, long location wrapping, edit sheet refresh, empty history and switching back to overview on device.
