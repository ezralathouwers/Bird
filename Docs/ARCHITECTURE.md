# Phase 1 decisions

`SpeciesRepository` isolates the sample catalog and multilingual search. Stable mock IDs do not derive from display names; observations record the taxonomy version used at entry.

`ObservationStore` is the main-actor observable view model; views publish changes only after persistence succeeds. `ObservationPersistence` allows replacement without coupling UI to storage. Phase 1 uses a version-named Application Support JSON file and atomic replacement. A read/validation failure is visible and blocks saving/export instead of silently creating a new empty file. No automatic corruption recovery is attempted.

JSON is a deliberately small local slice, keeping export and persistence inspectable without selecting a SwiftData/CloudKit schema before requirements are tested. This deviates from the preferred SwiftData option; revisit before adding sync or larger datasets. Future schema migration must preserve the v1 file, decode every supported version, and test recovery before replacement. Current export is a lossless Codable round trip; dates use Swift's default reference-date encoding, not ISO 8601.

Lifelist is derived from confirmed non-captive observations; the rules type exposes inclusion of captive records, with no settings UI yet. Uncertain records remain in history. Edits preserve UUID, creation date, taxonomy and source.

No licensed media was bundled. The in-chat screenshot guides the artwork layout. Add original artwork under Resources with author, license, source, view type, species ID, version and scientific-review status. Keep a reference copy under Design/References once an actual file is available. Final color/font approval and deployment target are outstanding.

## User revision — 16 November 2026

The latest explicit user direction supersedes the earlier five-tab/four-simultaneous-views specification: three detail tabs (Overzicht, Verspreiding, Waarnemingen), lighter beige, light action-icon strokes, no centered species-page navigation title, and one illustration per swipeable page with four accessible dot buttons. The back action remains native. Length uses horizontal arrows; wingspan uses an original outlined spread-wing drawing.

Castoro and DM Sans are bundled offline from google/fonts, with their SIL Open Font License files alongside. Original variable fonts are unmodified. PostScript names were inspected with fontTools: Castoro-Regular and DMSans-9ptRegular. UIAppFonts and resource build membership register both fonts. SwiftUI custom fonts scale relative to text styles. Native navigation/tab-bar chrome may retain platform fonts; font registration, rendering and any SwiftUI paging/bottom-tab interaction still require Xcode/device verification.

## Footer refinement — 16 November 2026

Latest user instruction explicitly adds a shallow habitat illustration, superseding the earlier ban on overview habitat art. The decorative 84-point footer is placed in a zero-spacing bottom safe-area inset on the overview, full width above native bottom navigation; it is hidden from VoiceOver. Its real crop, native tab-bar separator and inset behavior await Xcode verification.

Facts icons retain their semantic VoiceOver labels and now scale to 80%, with taupe at 50% opacity over ivory. Distribution is removed from overview facts, retained as its own tab. Habitat copy is shortened to “Rivieren, beken en meren” and gets the whole row; accessibility text sizes still wrap. Tabs use 12-point scalable uppercase DM Sans with 1.1-point tracking; the visible pill is shorter with a darker selected beige. Touch targets remain at least 44 points.

## Bottom navigation and Fraunces revision — 16 November 2026

Replaced the native prototype TabView navigation with a root-level, zero-spacing bottom safe-area inset. Its five equal-width slots are Ontdek, Identificeer, an unlabeled 30-point plus inside a 48-point circle, Sessies, and Lijst. The plus presents the existing observation form for the sole mock species; it is an action, not a selectable tab. Identification and sessions explicitly remain unavailable; Lijst contains history, export and lifelist. The habitat inset on species overview now sits directly above this root navigation inset, outside scrolling content. Bottom home-indicator safety is retained; no fixed device height or spacer positions the navigation.

Heading actions now use top alignment. Artwork and tabstrip share the full parent content width, with the extra artwork inset removed. All detail tabs share one 12-point font and tracking; selection changes background only.

Replaced Castoro with the unmodified original Google Fonts Fraunces variable font and OFL notice. The source font's registered PostScript name is Fraunces-9ptBlack; the SwiftUI title explicitly requests regular weight on that variable font. Actual variable-axis/font rendering needs Mac/iOS verification. DM Sans is unchanged.
