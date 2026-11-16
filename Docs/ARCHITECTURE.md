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

## Header and text refinement — 16 November 2026

Species actions move into the trailing native navigation toolbar, aligned on the same row as an explicit leading back button. Back dismisses to Ontdek. The heading is now English DM Sans first, Dutch Fraunces second, with the full content width available and wrapping retained. The three toolbar actions retain 44-point targets.

App-owned primary text uses dark brown-grey #4F453D, including a tinted secondary-copy variant. System-managed Safari/alerts retain platform styling. Main navigation uses ultra-light SF Symbol strokes and a 0.5-point center-plus circle. Lijst is renamed Logboek in the item, destination heading and help copy.

## Raised observation button — 16 November 2026

Logboek now uses the bird SF Symbol. The central add circle grows from 48 to 72 points (50%) and its glyph from 30 to 45 points; dark text-colour fill with ivory glyph. A reserved 21.6-point top region and matching negative safe-area-inset spacing expose exactly 30% of its diameter above the navigation separator, over the habitat. The entire circle stays inside the navigation container's bounds for hit testing, with no clipped/offset button target. The five slots remain equally distributed; the add action is an overlay at the exact horizontal center. Toolbar back and actions receive the same 4-point downward offset.

## Neutral grey and navigation typography — 16 November 2026

Primary text and observation-button fill change from brown-grey to neutral warm grey #4B4946; taupe accents change to #6B6864. Beige surfaces and habitat art remain intentional separate colours. The center plus is now an original 0.8-point stroke drawing, replacing the lightest available SF Symbol. Its solid 72-point circle has no border. Navigation captions are uppercase DM Sans with 0.8-point tracking and retain wrapping at small widths/large text sizes.

## Icon-only navigation — 16 November 2026

Removed all visible bottom navigation captions; retained explicit Dutch VoiceOver labels and selected traits. The four destination icons increase from 20 to 24 points. Identificeer moves 6 points left and Sessies 6 points right within their original equal-width button targets; the central plus remains unchanged and centered. Targets retain 56-point minimum height.

## Dark navigation surface — 16 November 2026

Bottom navigation now uses the shared dark neutral charcoal surface, extending beneath the home-indicator safe area, with ivory destination symbols. The raised central observation button uses selectedBeige, the exact same token as the active species-tab pill, with a charcoal hairline plus for contrast. Geometry, borderless circle, raised overlap and icon-only VoiceOver labels are unchanged.

## Interactive distribution tab — 16 November 2026

White bottom navigation with dark symbols; raised add button uses dark text token and ivory hairline glyph. Distribution gets a separate non-scrolling layout: heading, tabstrip, flexible interactive MapKit map. Artwork and habitat footer are omitted in this state. GeoJSON polygon loading and attribution are protocol-based, fit the camera to actual supplied ranges and expose loading, unavailable, malformed and offline states. No verified range dataset exists in the repository, so no fabricated species extent is displayed. See DISTRIBUTION_DATA.md.

## Species observation history tab — 16 November 2026

Waarnemingen now shares the compact fixed heading/tabstrip layout with Verspreiding. Only its history scrolls, with lazy rows showing date/time, location (or explicit missing-location text), count and confirmation state. Artwork, page dots and habitat footer are overview-only. Rows still open editing; changes update the observable store. All records for this stable species ID appear, including uncertain/captive entries; newest observations sort first, UUID breaks date ties. All-observation export stays in Logboek and is hidden from this species-specific view.

## Observation location detail — 16 November 2026

Removed count and status controls/labels from logging and history. Legacy fields remain in storage/export so older records are preserved: editing leaves their values intact; new explicit personal logs use the legacy defaults (count 1, confirmed, non-captive) without asking users to enter them. This also preserves existing lifelist behavior. These defaults are compatibility metadata, not a user-entered bird count.

Observation gains optional latitude/longitude; old JSON decodes without them, and validation requires either both absent or a finite, geographically valid pair. An optional map picker in the observation form records coordinates by user tap, without GPS permission or implicit geocoding. Name-only locations do not fabricate coordinates. Existing records can acquire a point via the map detail's edit button.

History row taps select a root-level observation overlay. The underlying guide/history stays mounted, preserving selected tab and scroll state. The overlay replaces species UI with an ivory date/time strip and full-space interactive map, retaining the root navigation. The central raised button becomes a light-beige close button with a fine dark X, restoring the previous list; choosing another navigation destination closes the overlay as well. The map marker is circular and uses the approved `<speciesID>-primary` image if available, otherwise an explicit generic bird placeholder because no primary illustration was supplied. Map tile offline limitations are shown via shared connectivity state. Editing remains available from the date strip.

## Floating observation information — 16 November 2026

The observation map now fills behind its top information panel rather than starting below a header. A rounded ivory overlay has 16-point outer margins and padding, showing Dutch species name first, date/time next and location name last. Long text wraps. Missing-location/offline messages stack below the information overlay rather than covering it. Editing stays in the panel with its 44-point target; bottom navigation and light close action remain unchanged. Automatic map chrome is hidden to avoid collision with the panel; native gestures remain available.

## Location-first observation rows and country badges — 16 November 2026

History rows lead with the location in scalable 20-point DM Sans and place date/time underneath in 13-point secondary text. Known countries outside Belgium show a right-aligned circular flag badge using native flag emoji; Belgian and unspecified/invalid countries show none. Country names are descriptive VoiceOver labels. No country is guessed from place names, device region or map center.

Observation now has an optional ISO region code that is absent for older records. The form offers an explicit optional country picker; codes normalize to uppercase. Country values survive local persistence and JSON export. Emoji artwork uses platform rendering; precise circular flag appearance needs device review.

## History total and map breathing room — 16 November 2026

History now starts with the count of matching observation records (not legacy bird quantities), with singular/plural text and zero support. The count derives directly from the same array used for rows, updates with the observable store and is hidden on load failure rather than implying zero. Distribution gains 16 extra points above the map, giving 32 points between the tabstrip and map. Other tabs keep their spacing.

## Overview measurement simplification — 16 November 2026

Removed length and weight from overview facts. Wingspan is now the only measurement, set in scalable 20-point DM Sans relative to title3, matching observation location typography. Habitat remains a separate normal-size row; small pale icons and descriptive VoiceOver labels remain unchanged. Simplified the facts stack to avoid duplicated habitat rows after removing the measurement group.

## Plain wingspan value — 16 November 2026

Removed the spanwijdte symbol and its reserved horizontal slot, retaining the 20-point value and descriptive VoiceOver label. Habitat follows after 8 points instead of 20; the source note stays a separate 16 points below. Removed the unused spread-wing shape.

## Observation metric and distribution spacing — 16 November 2026

The species Waarnemingen tab opts into a prominent count: the number is 40-point DM Sans relative to title3 (twice the 20-point location title), with a smaller 14-point baseline-aligned noun. Both share charcoal at 35% opacity, as requested, and one combined VoiceOver heading. Singular/plural and derived-record count behavior are retained. Logboek keeps its previous total styling. Distribution adds 32 points above the map on top of the existing 16-point stack gap, for 48 points total.

## Refined metric and restrained map gap — 16 November 2026

Reduced the distribution map gap to 24 points total (16-point stack spacing plus 8-point map padding). Previous generated mockup overstated the gap and is not a measured rendering. Species observation total now uses 60-point numeral (50% above 40) and 20-point noun matching row location type, both relative to title3 and at 35% opacity. Added 12-point vertical padding to the metric group.

## Redesigned observation form and location defaults — 16 November 2026

The form now has a selected-species image block, separate editable date/time pickers defaulting to Date() for new logs, a required location section (map first, editable name directly below), and a persistent bottom save button. Back arrow replaces Annuleren; removed the top save duplicate, notes UI, country picker, optional wording and map-location removal. Approved primary illustration is still absent; the image block uses a labelled placeholder. Hidden legacy notes are preserved on editing, not silently cleared.

Opening a new form requests foreground location permission, documented in Info.plist, and then a one-shot current fix. No background tracking. Denied/unavailable/stale fixes explain manual map selection as fallback. Picking a map point supersedes outstanding GPS callbacks. Apple reverse geocoding suggests a nature-area/point-of-interest name first, then locality/place/region, and derives the ISO country. Actual nature-area names depend on Apple's coverage; no guarantee is made. The user can override the name. Debouncing, cancellation and request IDs prevent stale suggestions from replacing a later point; a manual name isn't overwritten by late results.

Country is read-only and automatic, not a required manual field. Offline geocoding failures leave it unknown with an explicit message; a manually named valid point can still save offline. New form saves require both coordinates and a nonempty location name; storage continues to accept old name-only records. Coordinates/country/notes remain exportable. Location services use main-actor delegate callbacks with a preconcurrency conformance; Swift 6/SDK compatibility must be checked on Mac.

## Form header and simplified date fields — 16 November 2026

Form presentation is full screen from all three entry points, avoiding modal-sheet top inset differences. Back uses topBarLeading, the same 44-point target, 22-point light chevron and 4-point downward offset as species pages. The form title uses a principal toolbar item with the same downward offset. Date/time picker labels are visually hidden but keep explicit VoiceOver labels. Removed persistent map helper copy beneath the country; no divider is rendered there (the earlier generated preview introduced one). Lookup errors and the current-location action remain available.

## Automatically derived species logging badge — 16 November 2026

All three species tabs now show a small check-circle and Gelogd beside the English name if any saved observation matches the stable species ID. Otherwise an open circle and Nog niet gelogd appear. The full-width Dutch title remains below. State derives directly from published stored observations, so a successful save updates the badge without a separate flag that could drift. A load failure displays Status onbekend, never a false unseen state. Gelogd indicates a record exists (including legacy uncertain/captive records), distinct from confirmed lifelist eligibility. The badge has a descriptive VoiceOver label.

## Icon-only logging badges and fact alignment — 16 November 2026

Logging badges now use 44-point filled circles matching top action-button diameter, without visible copy: dark X on beige for not logged; light eye on muted khaki #85836B for logged. A question mark on beige preserves the unknown/error state. VoiceOver retains full status wording. The English-name row centers the circle vertically; Dutch title still uses the full width below. Fact rows explicitly fill the available width with leading alignment, placing the unadorned wingspan value at the tabstrip's left outer edge.
