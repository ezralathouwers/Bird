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

### Observation location detail

Added two XCTest methods: legacy decoding/preservation without coordinates, and coordinate validation/round trip (including partial, out-of-range and NaN rejection). Tests were not executed: no Swift/Xcode toolchain. `git diff --check`, source assertions and OpenStep source-membership checks passed. In Xcode verify row → full map → close returns to the same list/tab/scroll; 30%-overlapping close target; date/edit strip; picker tap/save/relaunch; no-coordinate and offline messages; circular illustration/fallback marker; legacy metadata retained on edit. No personal observations or coordinates were added to source control.

### Floating observation information

`git diff --check` and source checks passed: map-root layout, top overlay with 16-point margins, species/date/location order and missing-location fallback. This UI-only refinement has no new logic tests. In Xcode check full-map drawing behind the panel, long names and Dynamic Type, edit tap target, and clear marker placement. Native compilation remains unverified.

### Location-first history and foreign flags

`git diff --check` and source assertions passed for location-before-date typography and circular foreign-country badge. Added XCTest for Belgian/unknown suppression, foreign flag generation, normalization and country persistence round trip; legacy test asserts missing country remains nil. Tests remain unexecuted without Xcode. Verify flag emoji rendering, country picker, long location wrapping, Dynamic Type, row → map → close, and VoiceOver country announcement.

### History total and map spacing

`git diff --check` and source checks passed for count derived from filtered records, singular/plural display, load-error guard and distribution-only 16-point extra map padding. No new tests for these small display changes; existing species-history logic tests remain unexecuted without Xcode. Check list total updates after save and 32-point map gap in Xcode.

### Overview measurement simplification

`git diff --check` and source assertions passed for absence of length/weight facts, one wingspan row and matching 20-point/title3 typography. This display-only change adds no tests; rendered layout and Dynamic Type still require Xcode.

### Plain wingspan value

`git diff --check` passed. Source checks confirm a nil wingspan symbol, unchanged 20-point value and 8-point fact spacing. Native layout remains unverified without Xcode.

### Prominent count and larger map gap

`git diff --check` and source assertions passed for 40/14-point count typography, shared 35% opacity, species-tab-only opt-in and 48-point total map spacing. No new logic tests for these display changes. Native text wrapping/contrast and map layout remain to check in Xcode.

### Refined metric and restrained map gap

`git diff --check` and source assertions passed for 60/20-point total type, 12-point vertical padding, retained 35% opacity and 24-point total map gap. Visual verification still requires Xcode; generated images are illustrative and cannot establish exact spacing.

### Redesigned observation form

Added four XCTest methods covering place-name priority, required coordinates/name and automatic country, manual-name/latest-selection protection, and offline manual fallback. These were not executed without Xcode. `git diff --check`, project source-membership checks and plist permission-description validation passed. Xcode/device checks required: allow/deny/approximate location, current fix and map recentering, real reverse geocoding, changing map/name/country, separate date/time fields, no location-removal action, bottom save with keyboard and Dynamic Type, legacy notes preserved, offline save and cancellation. Primary species artwork is still a placeholder.

### Form header and simplified date fields

`git diff --check` and source assertions passed for both 4-point toolbar offsets, hidden date/time labels with accessibility names, removed helper paragraph and full-screen form entry points. No new logic tests for this display refinement. Compare actual toolbar coordinates across screens in Xcode, including status-bar safe area and Dynamic Type; exact rendered alignment is unverified.

### Species logging badge

`git diff --check` and source assertions passed for derived status and all three labels. Added a unit test for unseen → logged and other-species isolation; extended existing reload and corrupt-store tests for logged/unavailable status. XCTest remains unexecuted without Xcode. Check badge wrapping, first-save refresh, restart and VoiceOver on device.

### Icon-only logging badges

`git diff --check` and source checks passed for 44-point circles, eye/X symbols, khaki/beige fills, retained accessible status labels and leading fact alignment. Status derivation is unchanged; no additional logic tests. Native symbol contrast, alignment and long names require Xcode verification.

### Exact badge spacing

`git diff --check` and source checks passed for one shared header, 24-point action/status gap, equal 44-point circles and common trailing inset. This removes dependency on native toolbar/body insets for their relative positions. Pixel rendering and safe-area behavior still require Xcode validation.

### Pupil-free eye and habitat paragraph

`git diff --check` and source assertions passed for the shared 44-point diameter, pupil-free custom shape, removed habitat row and untruncated paragraph. Habitat facts were checked against Vogelbescherming's species guide. This visual change adds no tests; verify eye visibility, equal button sizes, 24-point spacing and paragraph line count in Xcode.

### Badge offset and body copy

`git diff --check` and source assertions passed for shared diameter, 6-point badge padding, 16-point light paragraph and 6-point additional paragraph margin. Native font-weight rendering and measured circle/spacing appearance remain unverified without Xcode. Generated mockups are not precise render tests.

### Overview tabstrip micro-spacing

`git diff --check` and source assertions passed for 20/28-point overview gaps and shared 0.75-point eye strokes. No new tests for this UI-only change. Exact visual spacing and fine-line visibility remain unverified until Xcode/device review.

### Name casing and artwork padding

`git diff --check` and source checks passed for shared English display formatting, existing plain 24–26 cm value and vertical carousel inset. No tests added for this small presentation change. Native font/layout rendering remains unverified without Xcode.
