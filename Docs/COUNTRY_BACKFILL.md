# Countries from stored observation coordinates

The Birda CSV lacks a country column. Previously the import preserved exact
coordinates but left countryCode empty, so valid map pins were absent from the
Countries screen. The updated app fills missing countries automatically for
existing observations and sessions, without re-importing or creating records.
New CSV imports infer countries during their background parse too.

## Lookup and performance

- The local, immutable index uses public-domain Natural Earth 1:10m admin-0 map
  units and ISO_A2_EH codes, retaining source vertices, holes and islands.
  Map units distinguish overseas ISO territories such as Réunion from mainland
  France, matching the app's ISO country model. Parts without usable ISO codes
  remain unresolved. There is no politically inferred replacement for these.
- A ~4.5 MB binary stores Float32 coordinates; exact source URL, SHA-256,
  binary SHA-256, feature/vertex counts and terms are in
  `Resources/CountryBoundaries.json`. Regenerate with
  `python Scripts/build_country_boundaries.py downloaded-map-units.geojson`.
- The index is loaded once and queried on a utility task, with bounding-box
  filtering, hole-aware point-in-polygon and coordinate deduplication. It does
  not render any polygons or load BirdLife distribution data. Land-country
  lookups require no GPS/location permission or network and do not block UI.
- Cartographic coastlines/borders are approximate, not a legal authority.
  Offshore/harbour coordinates or points without a unique polygon match are
  not blindly assigned the nearest country. The app queries Apple reverse
  geocoding for remaining unique coordinates, one request at a time with a
  1.5-second delay. Only Apple's returned ISO country is stored. Those specific
  coordinates are sent to Apple; the bulk local lookup stays on-device.
- Nil/invalid codes are never invented. (0,0) is not assigned a country. An
  observation on the open ocean can legitimately remain unknown. No-result
  requests are cached for 15 minutes; network/write errors pause online work
  and expose a retry action on Countries. Already completed work stays saved.

## Data integrity and lifecycle

`CountryRepairController` schedules on launch, normal store revisions and
foreground return. Revisions arriving during a pass request a follow-up pass
instead of cancelling/restarting every geocoding lookup. Backgrounding cancels
work; foregrounding resumes using the persisted current snapshot. Exact
coordinate matches group observations and sessions, not rounded geographic cells.

`ObservationStore.applyCountryResolutions` merges only valid missing codes,
rechecking each UUID and coordinate against current records before saving.
Existing known/manual country codes, notes, count, species, import metadata,
precise coordinates, timestamps, session boundaries and goals are preserved.
A session's country uses its own representative coordinate; it does not overwrite
countries on individual sightings within that session. Deleted/moved records
are ignored; unrelated edits made during lookup survive. One atomic persistence
write precedes publication, and a failed save leaves data/revision unchanged.
Country updates trigger normal backup scheduling when configured.

Countries shows progress and any lookup error; resolved countries appear without
waiting for all online requests. Unknown records remain visible as a count and
are not silently dropped from the history.

## Verification

Four Python tests execute an independent decoder of the actual bundled binary:
source-output hash/count consistency, cities/islands on both sides of the date
line, Réunion and other ISO territory handling, enclaves/holes and unknown ocean
points. The private supplied CSV was checked locally against this reference
lookup; no CSV rows, locations or country-annotated user archive are in Git.

Eight new XCTest cases cover the native index, resource corruption/invalid input,
persistence round trips, country projections, preservation of all other fields,
known/manual codes, stale/deleted coordinates, failed writes, offline paths
without geocoding, grouping of exact fallback coordinates, 0,0, negative-result
caching and pausing after network failures. They use synthetic fixtures and
mocked reverse geocoding, not live Apple requests.

Executed here: four Python dataset tests; Swift tree-sitter syntax and OpenStep
project/resource-target checks; `git diff --check`. XCTest, Xcode compilation,
iPhone timings and actual Apple coastal geocoding were not run on Linux.
