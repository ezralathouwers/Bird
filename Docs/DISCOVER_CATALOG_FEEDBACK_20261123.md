# Discover, search and catalog feedback — 23 November 2026

## Behavior

- Discover settings gear moves 22 pt closer to info while retaining separate
  44 pt touch targets. Sources opens fullscreen with the shared centered header.
- Add menu has 24 pt top clearance and less unused lower space, moving both
  observation and goal choices down. Discover has 20 pt extra bottom padding.
- Catalog pickers keep their search field above a result scroll view. A 24 pt
  ivory fade appears only after scrolling. Changing the query recreates only the
  result viewport, preventing a previous long-list offset from hiding matches.
  Empty results are explicit. Search normalizes punctuation and repeated spaces.
  The intermittent native blank-list report has not been reproduced on iOS here.
- Photo ID's image-to-location gap decreases from 36 to 12 pt.
- Local sightings settings persist a 1–50 km radius, default 5 km. The old source
  footer is removed; credits remain in Sources & licences.

## Combined public sightings

Native URLSession now reads Observation International's public around-point
endpoint alongside eBird. No new dependency, observer profile or media import.
Requests use `species_group=1`, radius in metres (maximum 10 km), 200-record pages,
and overlapping 14-day windows ending today, 13 days ago and 26 days ago. Ranking
enforces the final 30-day/radius boundary. Duplicate provider IDs are removed.
Pagination URLs are never followed directly. More than 30 pages, an empty page
with a continuation, or a failed page rejects that provider's incomplete result.
Public certain species-level observations are used; escapees and obscured or
missing positions are skipped. Scientific names must match unambiguously to an
active catalog species. Results are cached in memory for five minutes.

Provider local date/time strings determine descending order in the same nearby
area. A record without a time sorts at the start of its date; neither API provides
enough timezone information to establish an absolute global timestamp. Each bird
keeps the latest qualifying source link. If one provider fails, the other remains
visible with a notice. Above 10 km, a notice explains Observation.org's smaller
coverage. Without an eBird key, public Observation.org still works.

Read-only live checks returned HTTP 200 for all three dated windows, with
pagination (817, 1,059 and 997 records respectively for a 5 km Antwerp test).
Only counts/schema were retained in this report; third-party records were not
committed. Thirty-day single-window requests and 50 km requests are rejected by
the endpoint, which is why the adapter uses bounded windows/radius.

## Catalog audit

The pinned AviList catalog explicitly marks 151 species Extinct/(extinct).
They are excluded from active search, identification suggestions and illustration
production. All 11,173 source rows, historical IDs and model label positions are
retained so existing logs keep resolving. The active catalog contains 11,022 birds.
Possibly extinct, extinct in the wild and reintroduced species remain available.
See [ExtinctSpeciesCatalogAudit.csv](ExtinctSpeciesCatalogAudit.csv).

Requested Dutch names are corrected and recorded as reproducible builder
overrides. Norfolkbrilvogel is itself marked extinct in the source, so its corrected
name remains available for historical records rather than active search.

Six active birds still have no Dutch name: Slaty-masked Tinamou, Philippine Serpent
Eagle, Streak-fronted Antshrike, Vietnamese Cutia, Streaked Dacnis and Western
Hemispingus. No translation was invented. Another 23 active birds share English
and Dutch spelling (for example Hoatzin, Kakapo and Kea); these are not
automatically missing translations. See [SpeciesCatalogNameAudit.csv](SpeciesCatalogNameAudit.csv).

## Validation

- `python -m unittest discover -s Scripts -p test_catalog_visibility.py`: 3 passed.
- Swift tree-sitter syntax scan of app and test files: passed.
- Catalog source fingerprint, unchanged ID sequence and only two intended name
  edits relative to the previous commit: checked.
- XCTest regressions added for search normalization, historical extinct records,
  API bounds, overlapping windows, mixed chronology and provider fallback.
- `git diff --check`: passed.
- No Swift compiler, Xcode or iPhone simulator is available in this Linux
  workspace. Native compilation, XCTest execution and visual verification remain
  pending on macOS/iPhone.

Illustration generation remains paused at the user's request.

## Dutch names follow-up — 23 November 2026

The user supplied Dutch names for all six remaining active birds. They are now
applied verbatim and pinned in the builder/provenance overrides. No active bird
remains without a Dutch name. Vietnamese Cutia is explicitly confirmed in both
languages, bringing the same-spelling audit to 24 active species. Historical
extinct source rows may still lack translations. IDs and saved records are unchanged.
