# Short biographies and wingspans

Imported 20 November 2026 for all 11,173 addressable catalog records. Coverage is
**11,130 Dutch bios** and **1,313 reported wingspans**, not complete numeric data
for every bird. `SpeciesDetailsCoverage.json` records both missing-ID lists.

## Biographies

- 4,355 short Dutch Wikipedia excerpts from the already licensed BirdNET+
  Taxonomy v0.5-Nov2026 snapshot. Only the per-language `wikipedia` source flag
  is accepted. LLM translations/descriptions are excluded. Select up to three
  complete sentences, normalize whitespace; do not reword the excerpt or add
  inferred claims. Original article and contributor-history links are shown.
- 6,775 original short Dutch summaries from BIRDBASE v2025.1 primary habitat and,
  where source records unanimously agree, primary diet. These are general
  ecological statements, not independently written species monographs. Species
  known extinct in the catalog use past tense in these summaries.
- 43 taxonomy-unresolved species retain an explicit missing-bio message. No
  habitat is copied from an unverified parent species or inferred from family.

Exact existing IDs/scientific names or existing scientific aliases are required.
Wikipedia's source taxonomy or wording may predate AviList v2026; these imported
excerpts need later editorial review and are not labeled individually verified.
Coverage does not establish accuracy of every original source statement.

## Wingspans

Fox, Brunton & Shephard (2026), Figshare v1,
https://doi.org/10.6084/m9.figshare.32089083.v1, dataset CC BY 4.0 (checked via
Figshare API). Original XLSX SHA-256:
`6b55747a5761c08356d92c7a0b524b4e586c28a25316b0a6c1de3738db1d8eda`.

Import only rows with `needs_prediction == false` AND `model_used == empirical`.
Read `wingspan_reported_mid_all/min_all/max_all`, documented as centimetres;
never use wing chord, AVONET wing length, regression estimates or predicted
confidence bounds as wingspan. Match the Avibase concept ID, not names alone,
and require a unique source row. A reported range is preserved; otherwise a
reported midpoint is a single value, not an invented min/max range. Display
rounds to at most one decimal with Dutch formatting, no 'ca.' prefix or icon.
These are literature aggregates with population and measurement differences,
not a promise of one definitive physical range for every individual.

The previous kingfisher placeholder is replaced by an independently rechecked
24–26 cm factual guide value from Vogelbescherming Nederland. It takes precedence
over a differing Fox aggregate and retains its own source URL. No guide prose
was copied. Other numeric source records are imported without claiming an
individual expert audit. Missing spans remain 'Spanwijdte nog niet beschikbaar'.

## Runtime and rights

`SpeciesDetails.json` is bundled offline, checked against a pinned hash and all
catalog identities, and loaded once by `SpeciesDetailsCatalog`. It rejects
invalid ranges, unknown methods, duplicate IDs and malformed provenance. The
species overview now uses these records instead of kingfisher-only placeholder
copy. The source sheet shows bio provenance, original Wikipedia/contributor links
and each span's source. Existing catalog source-sheet callers remain supported.

The adapted catalog and Wikipedia excerpts are CC BY-SA 4.0; BIRDBASE and Fox
source data are CC BY 4.0. Full notices accompany the app in
`Resources/Licenses/SpeciesDetails-NOTICE.txt`, with existing catalog/BIRDBASE
license notices. No observation records, IDs, illustrations or range files change.

Reproduce (Python + openpyxl, maintenance only):

```
python Scripts/build_species_details.py /path/birdbase.xlsx /path/fox-wingspan.xlsx /path/taxonomy.zip
python -m unittest discover -s Scripts -p 'test_species_details_import.py'
```

Four portable importer tests passed. All 11,173 IDs, hashes, methods, bio lengths,
range bounds and project resource memberships were checked; 36 Swift files passed
syntax parsing and `git diff --check` passed. Three XCTest methods were added for
span formatting/rejection and bundled coverage. **No Swift build or XCTest ran**
on Linux. Xcode must verify decoding, source-sheet links, scrolling, long bios,
Dynamic Type and missing-data states on actual devices.
