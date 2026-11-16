# Phase 1 decisions

`SpeciesRepository` isolates the sample catalog and multilingual search. Stable mock IDs do not derive from display names; observations record the taxonomy version used at entry.

`ObservationStore` is the main-actor observable view model; views publish changes only after persistence succeeds. `ObservationPersistence` allows replacement without coupling UI to storage. Phase 1 uses a version-named Application Support JSON file and atomic replacement. A read/validation failure is visible and blocks saving/export instead of silently creating a new empty file. No automatic corruption recovery is attempted.

JSON is a deliberately small local slice, keeping export and persistence inspectable without selecting a SwiftData/CloudKit schema before requirements are tested. This deviates from the preferred SwiftData option; revisit before adding sync or larger datasets. Future schema migration must preserve the v1 file, decode every supported version, and test recovery before replacement. Current export is a lossless Codable round trip; dates use Swift's default reference-date encoding, not ISO 8601.

Lifelist is derived from confirmed non-captive observations; the rules type exposes inclusion of captive records, with no settings UI yet. Uncertain records remain in history. Edits preserve UUID, creation date, taxonomy and source.

No licensed media was bundled. The in-chat screenshot guides the artwork layout. Add original artwork under Resources with author, license, source, view type, species ID, version and scientific-review status. Keep a reference copy under Design/References once an actual file is available. Final color/font approval and deployment target are outstanding.

## User revision — 16 November 2026

The latest explicit user direction supersedes the earlier five-tab/four-simultaneous-views specification: three detail tabs (Overzicht, Verspreiding, Waarnemingen), lighter beige, light action-icon strokes, no centered species-page navigation title, and one illustration per swipeable page with four accessible dot buttons. The back action remains native. Length uses horizontal arrows; wingspan uses an original outlined spread-wing drawing.

Castoro and DM Sans are bundled offline from google/fonts, with their SIL Open Font License files alongside. Original variable fonts are unmodified. PostScript names were inspected with fontTools: Castoro-Regular and DMSans-9ptRegular. UIAppFonts and resource build membership register both fonts. SwiftUI custom fonts scale relative to text styles. Native navigation/tab-bar chrome may retain platform fonts; font registration, rendering and any SwiftUI paging/bottom-tab interaction still require Xcode/device verification.
