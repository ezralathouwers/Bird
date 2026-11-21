# Short biographies and wingspans

Imported 20 November 2026 for all 11,173 addressable catalog records. Coverage is
**11,154 Dutch bios** and **1,881 reported wingspans**, not complete numeric data
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

### Italian/German articles and dedicated guide fields — 21 November 2026

79 further empty span fields were filled: 15 from Italian Wikipedia, 37 from
German Wikipedia, 11 from Animal Diversity Web, 12 from Oiseaux.net, three from
Cornell All About Birds, and one from Nicole Bouglouan's Oiseaux-Birds guide.
Current coverage is 1,881 / 11,173 records (16.8%); 9,292 remain empty. All 11,154
biographies and all pre-existing measurements are preserved.

The completed article plans cover 2,932 Italian and 4,230 German revisions.
Species identities are checked against binome/Taxon_WissName and species-level
taxobox structure; known linked-entity concept mismatches are excluded. The
eligible counts are 2,709 and 4,081 respectively, with 14/16 known concept
exclusions. The 107 extracted phrases required further review; matching a word
or a scientific name does not establish measurement accuracy. Locale decimal
commas, metre/millimetre conversions and common unit words are supported. French
taxobox/unité handling has portable fixture tests, but no French bulk pass was
performed in this round.

Regional checks cover 76 ADW accounts discovered in cached English article
references and 21 targeted Oiseaux.net pages. All 97 HTML pages were retrieved;
59 had no usable explicit primary span field/identity match. The remaining pages
yielded 41 candidate fields, including erroneous single-wing/flipper values which
were not installed. Four further primary-guide values were inspected manually:
Cornell's Solitary Sandpiper, Red-breasted Nuthatch and Least Tern, with scientific
identity verified on their corresponding overview pages, plus Maguari Stork on
Oiseaux-Birds. A Cactus Wren Cornell check found no span field. The original HTML
and identity-page hashes are retained in the evidence; no guide prose or images
are bundled.

Dedicated exact-species guide fields can now resolve earlier deferrals. For
example, ADW explicitly reports an overall 55–62 cm range for Aegolius funereus;
this is not a synthetic union of separate sex ranges. For some other species,
the selected direct guide reports a different ordinary range from encyclopedic
summaries. The app records that guide's published value, not an invented
consensus or a promise of global individual extrema. Alternative values and
rejection reasons remain in the supplement evidence and review report. Old
deferral reports are historical snapshots; SpeciesDetailsCoverage.json is the
current missing-field inventory.

`MultilingualRegionalWingspanReview.json` records 79 accepted species and 41
deferred species, source counts, completed-plan statistics, targeted checks and
dataset-version checks. Source-version metadata still reports Fox v1 and
BirdWingData v2; no new numerical export was imported from that check. Neither
wing-chord values, unverified unit corrections, isolated type specimens nor
uncertain broader pre-split concepts were substituted for missing full spans.

Maintenance commands (downloads/candidate collection do not change app data):

```
python Scripts/fetch_wikimedia_wingspan_sources.py /path/taxonomy.zip /path/cache --language it
python Scripts/fetch_wikimedia_wingspan_sources.py /path/taxonomy.zip /path/cache --language de
python Scripts/collect_multilingual_wingspans.py /path/cache
python Scripts/fetch_regional_wingspan_sources.py /path/cache
python Scripts/collect_regional_wingspans.py /path/cache
```

The existing English cache layout remains compatible; other languages have
separate revision directories. Regional targets are in
`RegionalWingspanTargets.json`, not an acceptance list. ADW/Oiseaux pacing is
at least 8/10 seconds, respectively, with robots rules checked by the downloader;
rate/service errors stop the regional run. Cached successful pages and recorded
404/410 responses are skipped on resume. Full Wikimedia requests remain serial
and honor Retry-After. Install only reviewed records through the supplement
ledger; source licenses and per-language article provenance survive rebuilding.

Verification: 28 Python tests pass, covering foreign species-box identity,
decimal/unit conversion, empty trinome fields, partial ranges, dedicated guide
fields and rejection of AVONET/subspecies fallback cards. All 79 additions match
their cached evidence and exact identities; all 11,173 catalog IDs and every
old field were preserved. Hashes and repeat-import idempotence pass; all 36
Swift syntax trees parse and git diff --check passes. The native coverage test
expects 1,881. Native compilation, resource decoding, layout and XCTest still
require Xcode.

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
The current 28 portable importer/supplement/parser safety tests pass with
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
