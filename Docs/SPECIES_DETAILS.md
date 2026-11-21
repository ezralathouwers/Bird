# Short biographies and wingspans

Imported 20 November 2026 for all 11,173 addressable catalog records. Coverage is
**11,154 Dutch bios** and **1,802 reported wingspans**, not complete numeric data
for every bird. `SpeciesDetailsCoverage.json` records both missing-ID lists.

## Additions — 21 November 2026

24 previously missing biographies now have short sourced Dutch summaries:
22 adaptations of inspected English Wikipedia descriptions from the pinned
BirdNET+ snapshot, plus two factual summaries from species-specific scientific
accounts (Crypturellus resonans and Momotus castaneiceps). These use the explicit
source-summary-nl method; existing source-provided LLM descriptions remain
excluded. Nineteen biographies still lack sufficient exact-species evidence.
Some new summaries describe distribution/taxonomy only: habitat is never
inferred from a parent species when the source does not report it.

43 missing wingspans were added: 40 factual ranges from the dedicated flight-size
captions in Vogelbescherming's guide, with exact scientific identity from its
structured alternateName field; robin 20–22 cm from Natural History Museum;
great tit 24 cm (a single published value) from The Wildlife Trusts; great
hornbill 151–178 cm from Animal Diversity Web. Existing measurements are
preserved. The source dataset has only 1,424 empirical rows; matching names
alone cannot resolve differing Avibase concepts. No prediction or wing-chord
value is substituted. Coverage after this first supplement was 1,356 spans.

### Multilingual Wikipedia measurement pass

177 additional missing wingspans were filled from explicit numerical ranges in
the already licensed BirdNET+ Wikipedia descriptions (English, French, German,
Spanish, Italian and Portuguese). Only exact scientific-name matches and
per-language `wikipedia` flags are accepted. No LLM descriptions are used.
These use the existing source-checked-guide method, meaning reviewed source
wording, not a new independent scientific measurement. The source article URL,
language, matched measurement phrase, surrounding context and pinned snapshot
hash are retained per supplement. Multiple identical language descriptions are
corroborating text, not necessarily independent evidence.

`WikipediaWingspanReview.json` records the 177 accepted and 55 deferred species
from this pass. Conflicting language ranges, apparent wing-chord labels, source
unit/number errors, inferred spans, sex-only scope and uncertain split concepts
are deferred. A strict parser prevents body length, tarsus, wing chord or weight
from being picked up after a single-valued span or from the previous table row.
The parser is a candidate collector: it does not establish source accuracy or
automatically authorize an import. This is not a complete review of all
Wikipedia articles. Coverage after this pass was 1,533 spans. No existing content changed.

Collect new candidates without mutating bundled content:

```
python Scripts/collect_wikipedia_spans.py /path/BirdNET+_Taxonomy_v0.5-Nov2026.zip
```

Candidates default to `/tmp/wikipedia-span-candidates.json`; inspect them before
adding records with reviewed evidence to the supplement ledger. The collector
skips filled records, so rerunning it after this pass shows only remaining
candidates. Reapply the saved accepted decisions using
`python Scripts/supplement_species_details.py`.

Verification for this pass: all 177 additions were checked back against the
exact licensed snapshot phrase, source URL, scientific name and numerical unit
conversion. All 11,173 IDs, every pre-existing span and every biography were
preserved. Fifteen Python tests pass, bundle/ledger hashes match, a repeated
import is byte-identical, 36 Swift syntax trees parse and git diff --check passes.
The bundled coverage XCTest expectation was updated to 1,533. Native resource
decoding, Info links, compilation and XCTest still require Xcode.

### Full English articles and referenced Wikidata — 21 November 2026

269 additional empty fields were filled: 205 from full English Wikipedia
article revisions, and 64 source-reported single quantities from Wikidata P2050
(CC0). Total span coverage is 1,802 / 11,173 records (16.1%); 9,371 remain empty.
This broad pass does not establish that the remaining measurements do not exist.
It has not searched every language or regional/scientific source.

The English plan covered 9,461 exact-scientific-name links in the pinned BirdNET+
snapshot. All 9,461 full article revisions were downloaded in 190 serial
batches, with request pacing and server Retry-After respected. 9,344 pages passed
the taxobox/concept eligibility checks; 18 known Avibase-concept mismatches and
99 pages without an exact eligible scientific taxobox were not used. Full text,
not just introduction extracts, was scanned. The resulting 299 measurement
phrases required manual context, scope and unit review; this is conservative
pattern matching, not a complete semantic extraction of every article.

The global Wikidata query found 1,690 taxon-name/quantity rows, of which 189
distinct scientific names matched still-empty app records. Full entity revisions,
qualifiers, citations, species rank and Avibase IDs were then inspected. 101
entities were automatically deferred. In particular, quantity lower/upper bounds
encode uncertainty and are never assumed to be a biological range. Unreferenced
claims, qualified measurements, multiple active claims and concept mismatches
were also deferred. The remaining candidates received context/outlier review;
Wikipedia and Wikidata values were compared where both were available.

`LiveWikimediaWingspanReview.json` retains 269 accepted decisions, 82 manually
deferred decisions, the 101 automatic Wikidata deferrals, concept exclusions and
metadata for the 16 cited works. The 64 installed Wikidata records use the new
`source-reported-wikidata` method and remain single values. They are database
reports, not an assertion that the original papers were independently audited or
that the quantity describes every individual/population. Raw referenced P2050
statements, entity revisions, exact stored Avibase matches and response hashes
are retained in the supplement evidence. Wikipedia evidence retains the exact
article revision, permanent URL, normalized measurement phrase and short context.
Only numeric data are installed in the app; no new biography text was imported.

An already published overall interval can take precedence over a mean or narrower
interval contained within it. Separate male/female intervals are never merged
into an invented range. Simple convert/cvt templates and common wing-span spelling
variants are normalized; unsupported templates are left unparsed. Inconsistent
units, wing-chord labels, isolated specimens, inferred morphometrics and unresolved
source conflicts are left for review. All previously installed spans, biographies,
species IDs and observation data are preserved.

Reproduce candidate collection (standard-library Python; downloads stay outside
the repository and do not change the app):

```
python Scripts/fetch_wikimedia_wingspan_sources.py /path/taxonomy.zip /path/cache --max-batches 10
python Scripts/collect_wikimedia_live_spans.py /path/cache
```

Use the same cache to resume; omit max-batches for the entire remaining English
plan. The cache retains its initial title plan, entity responses and query result;
each Wikipedia response is keyed by request hash. The downloader uses full
revisions because MediaWiki limits full-article extracts to one page per request.
Source snapshots are cached for review, not committed in bulk. Candidate output
defaults to `/tmp/live-wikimedia-span-candidates.json` and must be reviewed before
adding evidence to the supplements. `Scripts/supplement_species_details.py`
reapplies saved decisions, validates Wikidata quantity agreement, refreshes hashes
and reinstates source licenses even after a base-data rebuild.

Verification: 22 portable Python tests pass, including unit conversions, article
identity, single-value/range confusion, uncertainty/qualifier rejection and
statement/value agreement. All 269 additions were checked against cached source
revisions and their stored evidence; 11,173 identities and every existing value
were preserved, hashes matched and repeat import was byte-identical. All 36 Swift
syntax trees parse; git diff --check passes. The native coverage expectation is
1,802; a new XCTest guards Wikidata single-value/source validation. Native
compilation, resource decoding, Info links and XCTest remain unverified without
Xcode.

Docs/SpeciesDetailsSupplements.json retains species IDs, evidence dates, source
URLs, numerical captions/page hashes and the licensed English basis of adapted
summaries. Scripts/supplement_species_details.py applies these records safely,
refreshes the bundle hash and coverage, and rejects overwrites, duplicates,
identity mismatches and invalid measurements. The base builder reapplies the
supplements so a rebuild preserves this work. Rights/credits remain under Info;
no technical or missing-data notices were added to ordinary guide screens.

Run `python Scripts/collect_vogelbescherming_spans.py` to collect new candidate
facts into /tmp/span_supplements.json without changing the app. Its parser skips
failed pages, ambiguous names and non-range captions; this is not a complete
audit of every source page. The 2026-11-21 pass checked all 345 guide links.
The current 22 portable importer/supplement/parser safety tests pass with
`PYTHONPATH=/workspace/work/validation-deps python -m unittest discover -s Scripts -p 'test_species_details*.py'`.
All 11,173 identities, preservation of existing values, bundled SHA-256 and
repeat-import idempotence were checked; 36 Swift syntax trees parsed and
git diff --check passed. Xcode decoding, layout and XCTest remain unverified.

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
- 19 species remain without a sourced biography after the supplements. No
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
individual expert audit. Missing spans remain nil in the dataset; ordinary guide
screens omit the measurement.

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
