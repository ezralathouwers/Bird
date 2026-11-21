# Estimated wingspan fallbacks

On 21 November 2026 the user explicitly authorized estimates: “Geschat is oke
hoor”. This supersedes the earlier reported-only scope for values shown in the
app. Estimates are stored separately; the original reported dataset is intact.

The app can now show **9,796 / 11,173 records (87.7%)**:

| Value source | Records |
| --- | ---: |
| Existing reported/guide values | 1,881 |
| Wingspan card values, treated as estimates | 225 |
| Fox order-model point estimates | 7,566 |
| Fox global-model point estimates | 124 |
| Still missing a usable value/identity match | 1,377 |

## Wingspan card data

The inspected Wingsearch snapshot contains 707 standard cards representing 707
scientific names: core/Swift Start, European, Oceania, Asia, Americas, and six
regional promo packs. 695 have numeric positive card wingspans; 12 use `*`.
The separate 40 Americas hummingbird mini cards use `0` as a game convention.
Neither `*` nor `0` is imported as a biological measurement. The standard-card
dataset matches 680 catalog scientific names exactly; its numeric fields fill
225 otherwise empty records. The 27 unmatched names are recorded for later
taxonomic review; no automatic alias/split/lump mapping is made.

Source: https://github.com/navarog/wingsearch, Git tree
`43e5036de9e68fa9c4fabaf4c760412a887adf05`, numerical fields from
`src/assets/data/master.json`, SHA-256
`64f22ae0c2e69e07983e6580c7f9f400b7361f05c53c9a202412afc9f841c6b9`.
The immutable raw snapshot URL is retained in the provenance JSON.

The official rules reference https://wingspan.rulepop.com/#wingspan explains
that some Asian values were extrapolated where reported spans could not be
found. Its hummingbird section also explains the special game comparison rule.
The data does not supply a measured-versus-estimated flag per standard card;
therefore all imported card values are conservatively tagged
`estimated-wingspan-game`. Only factual names, numeric values and source IDs are
used. Game code, card powers, flavor text, photos and artwork are not bundled.
Wingsearch's software is GPL-3.0; none of that software is an app dependency.

## Scientific model fallback

Fox, Brunton & Shephard (2026), Avian wingspan database, Figshare v1, CC BY 4.0:
https://doi.org/10.6084/m9.figshare.32089083.v1.
The already pinned XLSX SHA-256 is
`6b55747a5761c08356d92c7a0b524b4e586c28a25316b0a6c1de3738db1d8eda`.

Import only `needs_prediction == true` with a unique exact Avibase concept
match. An optional `avibase-` prefix and case are normalized; concept IDs are
never truncated or resolved by a familiar scientific name alone. Source names
and target names are retained separately when a genus has changed.

Use the author's selected `model_used` column: `wingspan_predicted_order` for
`order_model`, or `wingspan_predicted_global` for `global_model`. These are
published point estimates in cm. Do not substitute another model when the
selected point is invalid. Do not display the author's model-derived min/max
columns as an observed biological range. These rows use `estimated-fox-model`.

Both estimate methods store minimumCM == maximumCM. They are useful approximate
sizes, not independently measured or guaranteed individual values.

## Runtime and future updates

`SpeciesDetails.json` remains the reported-only source. The 7,915 estimated
fallbacks are in `SpeciesWingspanEstimates.json`, with an independent
`SpeciesWingspanEstimatesProvenance.json` count/hash check. Both JSON resources
are explicitly included in the app target. `SpeciesWingspanEstimatesCatalog`
validates point shape, known method/source, unique IDs and exact current catalog
identities. A missing/damaged estimate bundle cannot invalidate reported facts
or biographies.

Lookup priority is **reported > game estimate > Fox model estimate**. At runtime,
`SpeciesDetailsCatalog.details(for:)` adds a fallback only where the reported
field is nil. A subsequently sourced guide value automatically wins even if an
older fallback record still exists. The overview retains its existing number
format, without an icon or “ca.”. Source information identifies the estimate
method; ordinary species screens have no added technical notices.

`SpeciesDetailsCoverage.json` remains the reported-data research inventory.
`SpeciesWingspanCoverage.json` describes the effective combined display coverage.
The supplement importer refreshes both after adding new reported values, counting
only estimates still needed. Existing research collectors continue to search
unfilled reported fields, so approximate values do not prevent better sourcing.

Reproduce with maintenance Python + openpyxl:

```
python Scripts/build_wingspan_estimates.py /path/master.json /path/fox-wingspan.xlsx
```

The builder validates both pinned input hashes. `WingspanEstimateEvidence.json`
retains card ID/set or the exact Avibase/model/column selection per fallback.
Source-wide hashes and licenses are retained once in the provenance. Repeated
builds are deterministic. The builder never changes reported values or IDs.

35 portable Python tests cover source priority, sentinels, mini-card exclusion,
exact/ambiguous concepts, selected model column, point-only ranges, source
validation and later measured-data upgrades, in addition to the existing import
tests. Native tests check fallback precedence, formatting and bundled coverage.
Without Xcode, native compilation, bundle decoding, source-sheet layout, runtime
performance and XCTest remain unverified.

Validation performed on 21 November 2026:

- `python -m unittest discover -s Scripts -p 'test_species_details*.py'`: 35 passed.
- All 7,915 fallback values checked against the pinned card/XLSX inputs and
  per-record evidence; source hashes, exact identities and coverage verified.
- Rebuilt estimates and ran `python Scripts/supplement_species_details.py`:
  all seven data/provenance/coverage/evidence files remained byte-identical.
  The reported-data resource also matches the preceding commit byte for byte.
- Parsed 36 Swift syntax trees and the Xcode project; both new JSON resources
  appear exactly once in the application resource build phase and main group.
- `git diff --check`: passed. Syntax parsing does not establish Swift type
  correctness or replace the outstanding Xcode build and native tests.
