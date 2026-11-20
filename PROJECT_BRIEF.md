# Birding Companion — Project Brief

Version: 0.1 (16 November 2026)
Status: Product specification and initial implementation plan. Not yet a tested iOS application.

## 1. Product vision
Build a private, non-commercial, native iPhone birdwatching companion combining a personal lifelist and observation log, illustrated global bird guide, targets, local sightings, maps, statistics, sound recognition, and photo identification. Prioritize reliable records, attractive but practical field-guide design, offline use, and user ownership of data. No Android or social-network functionality is required.

The owner will begin work using Codex Cloud from an iPad while traveling, then use a MacBook Pro with Xcode for building, simulator tests, device tests, signing and iCloud entitlements. The iPad phase cannot verify a native iOS build unless a macOS build runner is actually available.

## 2. Confirmed decisions
- Platform: iPhone only, native SwiftUI.
- Look: modern UI with natural-history field-guide illustrations.
- Bird artwork: detailed naturalistic watercolor/colored-pencil illustrations, consistent style, primarily warm neutral backgrounds; accurate species anatomy and plumage.
- Overall UI background: the previously approved light, neutral ivory, **not** the later yellower/darker variant. Establish final hex codes by sampling the approved screenshot or user approval; do not invent a supposedly exact sampled color.
- Accent: restrained taupe / dark beige; avoid green active-state accents except where color conveys actual data (e.g., species artwork, range information if later shown).
- Typography: a Recoleta-like, characterful serif for the **Dutch species heading at top left only**. Use a readable modern sans serif (DM Sans or a licensed/equivalent font) for English name, navigation, tabs, measurements, labels and all other UI. Support Dynamic Type and long names.
- Data: local-first with planned iCloud/CloudKit synchronization.
- Species: global coverage; Dutch and English names, Latin names in the underlying model (Latin not prominent on species page).
- Main user data: personal observations, lifelist, targets, maps and statistics.
- Primary illustration style benchmark: the user-approved kingfisher reference and latest revised species-page mockup. Keep these image assets in the repository under `Design/References/` when provided; **do not assume Codex can access ChatGPT-generated images without upload**.

## 3. Core capabilities
### 3.1 Species guide
- Globally scoped species catalog with stable IDs and explicit taxonomy version.
- Dutch and English common names; scientific name stored for search, matching, import/export and disambiguation.
- Synonyms and taxonomic splits/lumps handled with versioned mappings; avoid using display names as database primary keys.
- Search by Dutch, English or scientific name; filters by family, location, seen/unseen, targets.
- Species detail: illustration(s), ID traits, audio, habitat, distribution summary, observations.
- Media licensing and attribution metadata per asset; allow placeholders when illustration unavailable.

### 3.2 Observations and lifelist
- Log one or more birds with date/time, latitude/longitude (optional), location name, count, notes, optional photo/audio, observation method, confidence, and provenance.
- Provide fast logging from a species page via a `+` button.
- Lifelist derived from confirmed personal observations, with user-editable rules for captive/introduced/uncertain records and taxonomy changes.
- Editable/deletable observations, duplicate checks, imports and exports (CSV/JSON); do not lose original imported records.
- Offline logging with later sync; conflict resolution must preserve user data.

### 3.3 Maps and nearby birds
- MapKit map of personal observations and optional hotspots.
- Nearby recent observations from an approved external provider (e.g., eBird API), subject to access and usage terms.
- Clearly distinguish **recently reported**, **seasonally expected**, and **detected by this phone**; never promise real-time bird presence from historical reports.
- Graceful offline fallback to cached observations and downloaded guide data.

### 3.4 Targets and statistics
- Personal wishlist/targets, optionally scoped to country, region, trip, or date.
- Show seen/unseen status, progress, and nearby recent reports when available.
- Statistics: species total, new species by month/year, observations by place/country, species by region, trips and milestones.
- Derive stats from observations; avoid independently stored totals that can drift.

### 3.5 Audio recognition
- Aim for embedded, optionally offline, real-time sound recognition resembling Merlin's workflow.
- Investigate BirdNET model integration and actual model/code licenses before redistribution or bundling. Confirm model suitability, iOS performance, supported taxa, and any attribution/share-alike requirements.
- AVFoundation microphone permission; optional local recording and spectrogram; model outputs suggestions with scores, not guaranteed identifications.
- A detection does **not** automatically become a confirmed lifelist entry.

### 3.6 Photo identification
- Camera and photo-library input; evaluate local Core ML/ONNX model or appropriately licensed external service.
- Do not assume proprietary Merlin or Birda recognition models/APIs can be embedded.
- Rank candidate species using image and optional date/location context; user confirms the identification before logging.
- The Google Images button on a species page should present a dismissible in-app sheet with an embedded web view or an explicit external-browser fallback, using a search URL for the **scientific species name** to reduce ambiguity. Do not scrape Google Images or claim access to a Google Images results API; respect provider terms, web-view restrictions and image copyrights. Make the sheet easy to scroll and close.

## 4. Species detail screen — latest approved direction
Target portrait iPhone layout (design reference 9:16; adapt to real device sizes and accessibility settings):

1. Top navigation: back arrow, centered sans-serif `Vogels van de wereld`. No bookmark, share, overflow or plus in this top navigation row.
2. Heading row: Dutch species name (e.g., `IJsvogel`) in moderately sized characterful serif, with English name (`Common Kingfisher`) below in sans-serif. No visible Latin name here. Long names must wrap or scale within sensible bounds rather than clip.
3. Three small circular icon-only buttons aligned to the right of the heading: sound, image gallery/Google Images, and `+` to log an observation. Use dark icons and subtle beige borders, generous tap targets (at least 44×44 pt), accessibility labels. Sound plays authorized species audio; gallery opens a dismissible scrolling web/image search sheet; plus opens a log-observation sheet.
4. Large hero illustration of the bird, with three smaller secondary illustrations arranged to fit. For the kingfisher: flight, front and rear views. No captions under the secondary views. No habitat-scene illustration and no distribution map on the overview screen.
5. Small carousel/page indicator dots where appropriate; only display them if swiping actually changes content.
6. A clearly distinct rounded, darker-beige tab bar with `Overzicht`, `Herkenning`, `Geluid`, `Verspreiding`, `Waarnemingen`. Selected tab is an ivory rounded pill **inside** the beige bar. All labels in sans serif, including selected tab; **no underline and no rule directly below the tab bar**. Allow horizontal scrolling for smaller screens and large text.
7. Overview facts: icon + value only (no `Lengte`, `Gewicht`, `Habitat` etc. labels). Example values for kingfisher: `16–17 cm`, `26–46 g`, `24–26 cm`, `Rivieren, beken, meren en waterrijke gebieden`, `Europa, Azië, Afrika`. Use small, consistent, warm taupe/dark-beige icons in **one visual style**; prefer filled or consistently weighted glyphs, not a mix of outline and filled styles. Use separators sparingly; maintain readability and accessible labels in VoiceOver even though visible labels are omitted.
8. Bottom navigation (design prototype): `Soort`, `Waarneming`, `Locaties`, `Lifelijst`, `Info`, with monochrome/taupe selected state. Treat labels as provisional and validate navigation information architecture before scaling.
9. Overall UI: light neutral ivory background; charcoal text; minimal color outside naturalistic illustrations. Do not accidentally drift toward yellow parchment.

Note: Generated mockups are visual references, not literal implementation specifications for text or facts. Validate scientific values and illustrations independently. In the most recent mockup the serif still appears in the selected tab; **correct this in implementation** so only the Dutch species title is serif.

## 5. Recommended technical architecture
- Swift 6-compatible code, SwiftUI UI, MVVM/lightweight feature-oriented architecture with protocol-driven services; avoid unnecessary frameworks.
- SwiftData for local observations, targets, trips and cached taxonomy metadata where suitable; consider a read-only bundled SQLite/JSON species catalog if 11k+ taxa makes that simpler and more robust.
- CloudKit/iCloud sync after local persistence is stable. Validate CloudKit/SwiftData capabilities and entitlement requirements in Xcode; design explicit migration, sync/error states and export/backups.
- MapKit + CoreLocation for maps and optional GPS; handle permission denial and approximate location.
- AVFoundation for microphone/recording and playback.
- Core ML/ONNX Runtime Mobile (subject to feasibility tests) for on-device inference.
- URLSession and typed API clients for external bird data; keep API keys out of git and source code.
- Assets: separate `BirdArtworkLibrary` with species IDs, views, license, author/source, version, review status and thumbnail/full-resolution variants.
- Privacy: request permissions only when needed; local-first; no tracking SDKs or unnecessary analytics.

### Suggested modules / folders
```
BirdingCompanion/
  App/
  DesignSystem/
  Features/
    SpeciesGuide/
    Observations/
    Lifelist/
    Targets/
    Maps/
    Statistics/
    SoundID/
    PhotoID/
  Models/
  Persistence/
  Services/
    Taxonomy/
    NearbySightings/
    CloudSync/
    Media/
  Resources/
  Tests/
Design/References/
Docs/
AGENTS.md
PROJECT_BRIEF.md
```

## 6. Data model (initial proposal)
- `Species`: stable internal ID, taxonomy authority/version, external IDs, scientific name, English and Dutch names, synonyms, family/order, status.
- `SpeciesArtwork`: ID, species ID, view type, local asset path, thumbnail path, generation/reference details, rights/license/attribution, review state.
- `Observation`: UUID, species ID, observedAt, createdAt, coordinates optional, location label, count, notes, evidence links, identification status, source, imported external ID.
- `ObservationMedia`: UUID, observation UUID, media type, local/cloud file reference, rights, capture date.
- `Target`: UUID, species ID, scope/trip ID optional, status, priority, notes.
- `Trip`: UUID, title, date range, optional region.
- `SoundDetection`: UUID, model/version, detectedAt, candidate species, score, audio reference, review state; not automatically a confirmed observation.
- `ImportBatch`: UUID, source, import date, original filename/hash, mapping version, results.
- `TaxonomyCrosswalk`: authority/version/external ID to internal species ID, with split/lump notes.

Use explicit migration strategies and unit tests for observation import, lifelist counts, and taxonomy matching.

## 7. Data and licensing checkpoints
- Evaluate eBird API eligibility, authentication, quotas, caching and attribution; never assume unlimited use or full public data coverage.
- Choose one primary taxonomy and a versioning policy; reconcile Dutch names with a documented language source. IOC/eBird naming can differ.
- Audio libraries (including Macaulay Library) and images require individual usage-rights review; don't silently bundle copyrighted content.
- Generated artwork may contain inaccurate field marks: review against reliable references and record review status.
- Avoid copying Birda or Merlin's UI assets, proprietary databases or models. These are inspiration, not implementation dependencies.
- Fonts: DM Sans can be evaluated with its license; a Recoleta-like serif should be properly licensed or replaced with a suitable licensed alternative. Do not include unlicensed font files.

## 8. Delivery phases
### Phase 0 — Repository and specification (iPad/Codex Cloud)
- Private git repository; add this brief, AGENTS.md, README and `.gitignore`.
- Decide deployment target after checking actual Mac/Xcode and iPhone compatibility; don't guess.
- Build initial SwiftUI app structure with mock/sample data, no secrets.
- Add architecture notes, data schema, test plan and assumptions log.

### Phase 1 — Kingfisher vertical slice (iPad code, Mac test later)
- Implement design tokens and reusable UI components.
- Implement kingfisher species page with all specified typography, layout, three action icons, tab strip and fact rows.
- Use user-provided approved kingfisher image as a repository asset **only after the user uploads it**; otherwise use an explicit temporary placeholder and document it.
- Implement basic observation creation/editing in local persistence; gallery sheet and sound action can use honest placeholder/error states until properly integrated.
- Add preview fixtures, unit tests for models and view models, accessibility labels.
- Do not claim simulator/device tests succeeded on an environment without Xcode.

### Phase 2 — Local birding essentials
- Species catalog ingestion and search, observation history, lifelist derivation, targets, CSV/JSON import/export, duplicate review.
- Add test fixtures for taxonomy changes and sightings across countries.

### Phase 3 — Maps, nearby data, statistics
- MapKit observations and nearby reports, caching and API failure states, personal dashboards.

### Phase 4 — CloudKit sync
- Configure entitlements/signing and validate on real devices; migration, conflict handling, offline-first recovery.

### Phase 5 — Sound and photo ID
- Validate licensing and inference performance; integrate audio pipeline first, then photo model; compare identification outputs against manually verified benchmark samples.

### Phase 6 — Global illustration library
- Start with 10 approved species as an artwork quality pilot: IJsvogel, Blauwborst, Hop, Bijeneter, Oehoe, Zwarte specht, Baardman, Purperreiger, Himalayamonal, Stellers zeearend.
- Keep reference style consistent, review anatomy/diagnostic features, generate crop-friendly hero assets, archive provenance, and only then scale toward global coverage.

## 9. Acceptance criteria for first usable milestone
- Repo opens as a legitimate Xcode project once on a Mac; all actual build results documented truthfully.
- Species detail shows correct Dutch and English names and follows the approved kingfisher layout.
- Only Dutch species heading uses serif; everything else sans-serif.
- Tabs are a rounded beige container with an ivory selected pill and no underline.
- Audio, image and plus icons are accessible, circular and correctly positioned.
- Plus button opens an observation form; saved local observation survives app restart and appears in history/lifelist.
- Google Images action opens a dismissible, scrollable view or an explicit safe fallback; no scraping.
- Data is exportable; app works without network for core logging.
- Tests cover observation save, lifelist calculation and search by Dutch/English name.

## 10. Open decisions to resolve before production
- Actual MacBook Pro chip/RAM, Xcode version, iPhone model and deployment target.
- Final approved UI colors sampled from source visual, and selected licensed font families.
- Taxonomy authority and Dutch-language names source.
- iCloud account and developer signing/entitlement readiness.
- External API terms and access; photo/audio model rights.
- Whether the user wants a persistent 5-tab layout or a revised information architecture after initial prototype.

## 11. Immediate Codex task
Read `PROJECT_BRIEF.md` and `AGENTS.md`. Set up a clean, compile-ready-in-principle SwiftUI repository and implement Phase 1's kingfisher species-detail vertical slice using sample data. Do not add unverified copyrighted assets or API keys. Keep each change reviewable. Explain exactly what can be verified in the current environment and what must await Xcode on the user's MacBook Pro. Provide an ordered checklist for first Mac setup and simulator test.


## Latest approved media direction — 19 November 2026
Each species requires five distinct assets: (1) a classic right-facing illustration for compact list/form/map contexts, (2) a dynamic, compositionally distinctive illustration for the species-detail first slide, (3) a front illustration for slide 2, (4) a rear illustration for slide 3, and (5) a flight illustration for slide 4. Dynamic does not always mean movement: species-specific behaviour and composition can add interest. Examples: hovering kestrel, pecking great spotted woodpecker, kingfisher with fish. This replaces earlier hero/flight/front/rear slide ordering. Never silently use the classic portrait as a dynamic hero.


## Full world species foundation — 19 November 2026
The user's expanded scope includes all species, regardless of Sound ID support. The guide now uses all 11,172 species in AviList v2026 (the authority underlying BirdNET), supplemented by licensed BirdNET Dutch names/aliases and sound mappings. A separate BirdNET compatibility concept is retained without rewriting existing IDs. Species pages are data-driven templates; missing illustrations and scientific fields remain explicit. See `Docs/WORLD_SPECIES_PAGES.md` for completeness, provenance, license distinctions, stable-ID rules and phased content rollout.


## Shared habitat illustrations — 19 November 2026
Species-detail footer landscapes are shared by habitat scene, not generated per species. The initial scene library contains 24 reusable landscape types with one source-checked primary selection and optional secondary habitats per species. Unassigned species do not inherit an arbitrary footer. See `Docs/HABITAT_ILLUSTRATIONS.md` for scene briefs, actual assignment coverage and the shared 84-point footer renderer.


## Provisional habitat footer assets — 20 November 2026
All 33 shared habitat scenes now have provisional watercolor artwork approved
for implementation. Compositions rise organically toward the left and right,
with a lower open center and complete objects. The urban variant uses modern
city buildings rather than a village. The shared renderer fits each complete
scene into a 160-point footer above navigation, replacing earlier cropped
84-point rendering. See Docs/HABITAT_ILLUSTRATIONS.md for provenance and native
verification still required.
