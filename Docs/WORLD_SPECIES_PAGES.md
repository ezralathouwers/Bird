# World species pages — 19 November 2026

## Delivered foundation

The guide now includes **all 11,172 species-level entries in AviList v2026**, not just the 9,788 bird classes in Sound ID. Orders, families, genera and subspecies are not counted as additional species. Extinct and possibly extinct species remain included. The official AviList Explorer dataset was used after the XLSX endpoint refused automated downloads; no protected source was bypassed.

The published BirdNET taxonomy snapshot contains 11,022 bird entries. Exact comparison found 151 AviList species missing there and one additional BirdNET concept (`Corvus cornix`). The missing AviList species are added with names from the official list; the extra BirdNET concept remains a separate compatibility entry so existing detections/logs are not silently merged. Consequently there are **11,173 addressable pages**, of which 11,172 belong to the official checklist. There are 1,385 records without a sound-model output. The model is neither a completeness filter nor a requirement to log a bird.

Every entry opens the shared SwiftUI species page with the correct stable ID, names, logged-status badge, manual observation action, personal history and the four illustration positions (dynamic/front/rear/flight). Existing distribution loading and missing-content states apply per species. Classic thumbnails remain separate. Pages are data-driven; there are not eleven thousand duplicated Swift files.

The same cached catalog is used by Discover's whole-catalog search, the central observation picker, retrospective/live session bird search and checklist creation. Search includes aliases and Dutch/English/scientific names, independent of logged status and location. Lists use lazy rendering. Nearby frequency data is still a separate unconfigured feed; the explicit full-catalog fallback is not presented as local likelihood.

All 250 AviList families are carried into the guide. Existing Dutch family labels are preserved for the pilot families; other family headings use the official Latin family name pending Dutch localization. For 158 records the Dutch source name is absent; English is used instead of inventing a translation.

## Stable IDs and taxonomy

- Six existing sample IDs and taxonomy-version strings are preserved.
- Existing BirdNET-backed entries retain their `birdnet-v3:BN…` ID and saved sound-label version where applicable.
- AviList species without a BirdNET ID use a namespaced Avibase-derived `avilist:…` ID.
- The sources are pinned to AviList v2026 and BirdNET Taxonomy v0.5-Nov2026, the same underlying AviList authority referenced by BirdNET. No old observations, sessions, goals or pins are rewritten.
- BirdNET IDs are pre-1.0 upstream identifiers and may change later. Future dataset updates require an explicit crosswalk and must not regenerate existing app IDs blindly. The importer rejects changed source checksums pending review.

`SpeciesGuideCatalog` validates a bundled SHA-256 and declared record counts, caches lookup/search data, and exposes a visible failure state with six-species fallback if the catalog cannot load. Recognition label lookup resolves through this same catalog; a missing sound label cannot remove a guide page.

## Sources and licenses

- AviList Core Team. 2026. AviList: The Global Avian Checklist, v2026. https://doi.org/10.2173/avilist.v2026 — CC BY 4.0.
- Official structured source: https://explore.avilist.org/data/avilist-2026.json (downloaded and SHA-256 pinned).
- BirdNET+ Taxonomy v0.5-Nov2026, https://birdnet.cornell.edu/taxonomy — CC BY-SA 4.0, immutable archive in https://zenodo.org/records/24362980.
- `WorldSpeciesCatalog.json` and the derived content-inventory CSV are adapted species-only/name/ID/family projection, distributed under CC BY-SA 4.0 with changes and credits recorded in bundled notices and provenance. Model weights and the original recognition-label resource retain their separate Apache-2.0 license.
- No external images, sound examples, descriptions or range polygons were imported. Their separate licenses are not assumed to be covered by the names/catalog license.

Credits and license links are available from catalog search and species pages. `WorldSpeciesCatalogProvenance.json` includes counts, source hashes, modifications and the compatibility exception.

## Remaining content, and how to fill it

The catalog is complete to the selected checklist version; the illustrated scientific content is not. Current actual artwork coverage is classic 6, dynamic 2, front 0, rear 0 and flight 0. No species has all five reviewed assets yet. Most overview descriptions, span values and range polygons remain explicit placeholders. Sound-model support is not a licensed example audio recording for the species speaker button.

`SpeciesContentInventory.csv` records the state of all 11,173 pages. `SpeciesContentCoverage.json` gives totals. Rebuild with `python Scripts/species_content_inventory.py` after adding assets. This makes missing material reviewable before scaling.

Recommended work batches:

1. Finish a ten-species pilot using the existing six, kestrel, great hornbill, bluethroat and hoopoe. For each: five distinct illustrations, accurate anatomy/field marks, reviewed Dutch description and habitat, sourced span, licensed audio and a separately licensed distribution source.
2. Review the artwork and content template on a small iPhone, long names and Dynamic Type. Document sources/licenses and approval status per asset/field; retain source originals.
3. Fill common local birds by family, then European birds, then regional families worldwide. Prioritize the owner's logged/checklist species when those device records become available.
4. Automate ingestion, coverage reports and asset validation; keep source review and species-specific illustration composition in the loop. Never mass-fill all pages with unsourced facts or reuse one dynamic pose for every species.

## Reproducibility and verification

`Scripts/build_world_catalog.py` consumes the pinned official AviList JSON, the immutable BirdNET taxonomy ZIP, and bundled sound labels. It validates counts, IDs and all model mappings and emits the adapted catalog/provenance. Run with `--avilist-json <downloaded-file> --taxonomy-zip <downloaded-archive>` from the repository root.

Available checks: source ZIP MD5/SHA-256, strict import checks, unique IDs and output-index mappings, all model species retained, inventory generation, Swift syntax parsing, OpenStep source/resource membership and `git diff --check`. Five added XCTest methods cover full coverage/families, a non-sound species searchable/loggable, old IDs and compatibility preservation, the long Dutch hornbill name and alias matching without ID changes.

Native build, XCTest execution, startup/search performance and 11k-row scrolling/navigation still require Xcode/iPhone. These checks have not been represented as passed.
