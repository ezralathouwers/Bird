# Distribution map data

The Verspreiding tab is a native interactive MapKit map. It replaces the scrollable artwork layout, puts the tabstrip below the heading, and fills the remaining space above navigation. Overview keeps the artwork. MapKit base tiles can require network and aren't guaranteed offline; NWPathMonitor provides an offline message. This is a distribution overlay, never a claim of current bird presence.

No verified kingfisher distribution dataset was supplied. Consequently **no scientific area is bundled or drawn**. The app explicitly reports unavailable range data while keeping map gestures usable. Do not replace this with an unlabelled hand-drawn approximate range or occurrence-density layer.

To supply a dataset, obtain a licensed, scientifically reviewed WGS84 GeoJSON FeatureCollection. Use Polygon or MultiPolygon geometries, with top-level nonempty `source`, `license`, and `version` strings (GeoJSON foreign members). Name the file `sample-alcedo-atthis-range.geojson` for the current mock ID and add it to the app Copy Bundle Resources phase. Before production, align stable IDs and taxonomy versions. Preserve source attribution, seasonal/presence semantics and review status; the current single-style renderer does not distinguish seasonal ranges.

The loader rejects missing provenance, non-area geometry and empty collections. Polygon holes and multipolygons are handled through MapKit's decoder; the camera fits the loaded geometry. Provider implementations can replace the bundled repository without changing the map UI. There is no automatic download, paid provider, taxonomy change or new credentials.

Mac checks: load a known licensed fixture, confirm outline and holes align with the basemap, verify pan/pinch/rotate and compass, source attribution, offline/missing/malformed states, tab switching and restored overview, full-height layout on short iPhones and large Dynamic Type. Large datasets may require simplification and asynchronous decoding before production; current local decoding is synchronous.

## BirdLife DataZone assessment — 16 November 2026

User-proposed source: https://datazone.birdlife.org/ . Official dataset information describes species range boundaries in file-geodatabase format, not an unrestricted GeoJSON API:
https://datazone.birdlife.org/dataset-information

Non-commercial access is requested via:
https://datazone.birdlife.org/contact-us/request-our-data

The current terms require use for the requested purpose, appropriate citation/version, and restrict redistribution. Website scraping is prohibited. Raw or converted range files must not be placed in this now-public GitHub repository unless the actual permission explicitly allows it:
https://datazone.birdlife.org/terms-and-conditions

No request has been submitted and no BirdLife polygons have been downloaded. A source proposal does not establish that permission has been granted. The integration remains blocked on access and confirmation of permitted private offline app use. BirdLife's taxonomy is the dataset's reference; choosing these polygons must not silently replace the app's unresolved taxonomy authority.

### Prepared request text (not sent)

I am building a private, non-commercial native iPhone birdwatching app for personal use. I would like species distribution polygons, initially for Common Kingfisher (Alcedo atthis), and potentially worldwide bird coverage later. The intended use is an interactive distribution map with optional offline storage on my own device, with source/version attribution and preservation of presence, origin and seasonality attributes.

Could you provide access to the relevant dataset and confirm whether extraction and conversion to WGS84 GeoJSON and inclusion in my private app installation are permitted? The app source repository is public, but your data would be kept outside it and would not be redistributed. Please specify required citation, version information and any restrictions on screenshots, app packaging or derived map displays.

### Next implementation after access

Keep the original licensed archive and metadata private. Inspect actual layer/schema and species identifiers, select Alcedo atthis without losing seasonal/presence attributes, transform to WGS84, validate polygons/holes and provenance, and preserve originals. Add seasonality-specific rendering/legend before presenting combined seasonal polygons as one area. Bundle only as permitted, in a private local build; do not commit restricted files or archive download links. Test against the official reference map in Xcode.


## Configured BirdLife source — 20 November 2026

`Resources/SpeciesRangeSource.json` now selects BirdLife International DataZone
as the distribution provider. It includes the official homepage, data-request
and terms links. The actual release, license notice and citation remain null;
access is explicitly `awaitingPermission`. The species map uses
`ConfiguredSpeciesRangeRepository` by default and shows this pending state,
source link and request link. The configuration is bundled in the Xcode target.
No API endpoint, credentials, licensed dataset or granted rights are invented.

The public dataset-information and request pages were checked again: worldwide
ranges are supplied as a file geodatabase following BirdLife taxonomy, with some
species omitted. Non-commercial access is requested through the form; commercial
use is directed to IBAT. Birda's use of BirdLife does not provide rights for this
app. No form was submitted on the user's behalf.

After receiving access, inspect the actual grant and source metadata before
activating the private build. Record the real release in `datasetVersion`, the
required license notice and exact attribution in `licenseNotice` and `citation`,
then set access to `licensed`. The loader rejects incomplete licensed metadata
and a GeoJSON version differing from the configured release. This is a local
configuration switch after review, not proof of legal permission.

The configured loader currently delegates to the existing local bundled GeoJSON
loader. It does not download or convert geodatabases. The earlier conversion,
taxonomic crosswalk, seasonal rendering and scientific checks remain necessary.
Keep licensed files in a private checkout/build location outside this public
repository, and package them only if the grant permits it. Do not change app
species IDs to BirdLife IDs. Missing per-species files remain explicitly unavailable.

Validation here: JSON configuration and Xcode resource references checked;
Swift syntax parsed; four XCTest methods added for pending access, metadata
requirements and unknown access states. XCTest execution, compilation and MapKit
layout/navigation still require Xcode. No actual distribution overlay can be
validated until an authorized dataset is available.


## Approved access, download blocked — 20 November 2026

The user confirmed BirdLife approval and supplied a download link. The bundled
configuration now records `approvedAwaitingFiles`; the map no longer prompts
for an access request and distinguishes this from a licensed, validated local
release. No dataset version, citation or license text has been invented.

The execution environment's network proxy returned HTTP 403 at CONNECT when
accessing the supplied Azure Blob host. Retrying after granted network access
and an escalated shell request produced the same proxy refusal. This is not
evidence that BirdLife rejected the user's approved request or that the download
link is invalid. No archive bytes were received, so contents, metadata, terms,
layer schema, taxonomy and seasonal coverage remain uninspected. The private
access link has not been committed. No data files were added to the repository.

Next step: obtain the archive as an uploaded file or in a workspace outside the
Git checkout; inspect its original metadata and terms, retain the source,
implement conversion and reviewed taxonomic mapping, and only then activate the
local licensed dataset. An uploaded archive is needed here because the proxy
prevents downloading directly. Native rendering and XCTest execution still
require Xcode.

## Local GeoPackage inspection — 22 November 2026

The user unpacked the 4.15 GB archive on their Mac. Their screenshot shows
`BOTW_2025.gpkg`, an XLSX handbook and a DOCX metadata document. The actual
schema and source documents have not yet been supplied, so filenames alone do
not establish field meanings, license notice, citation or dataset version.

A standard-library-only local inspector is now available:

1. Download `Scripts/BirdLife-inspectie.zip` from this branch and unpack it.
2. Double-click `Inspecteer-BirdLife.command` and choose `BOTW_2025.gpkg`.
3. Upload the generated `BirdLife-inspectie.json` from beside the GeoPackage,
   together with the small XLSX and DOCX source documents.

If macOS blocks double-clicking, open Terminal, type `bash ` (with a trailing
space), drag `Inspecteer-BirdLife.command` into the window and press Enter.
Python 3 is required; no pip, Homebrew or GIS dependency is needed. Xcode's
command-line tools normally supply Python 3. A command-line alternative is:

```sh
python3 Scripts/inspect_birdlife_geopackage.py /path/to/BOTW_2025.gpkg
```

The inspector opens SQLite with `mode=ro` and `query_only`, reads declared vector
layers/column names/geometry types/SRS, and selects at most five sample attribute
rows from a fixed allowlist per layer (up to 25 layers, with a limit flag).
It never selects geometry blobs, exports ranges, hashes/scans the whole 4 GB
file, installs software, sends data over the network or changes the app/source
configuration. The report omits absolute paths and arbitrary metadata text. Raw
GeoPackages, geodatabases and local inspection reports are ignored by Git.

Tests: `python -m unittest discover -s Scripts -p test_birdlife_geopackage_inspection.py -v`
(two passing tests using fictional data: byte-identical source before/after,
nontrivial paths, schema/sample output, no geometry/private-note/path leakage,
and rejection of non-GeoPackage files). `bash -n Scripts/Inspecteer-BirdLife.command`
and `git diff --check` pass. Actual BOTW schema, macOS file picker execution,
conversion, licensed range activation and native MapKit overlays remain pending.


## Verified BOTW 2025.2 local conversion — 22 November 2026

The uploaded inspection establishes one `all_species` layer with `geom`
MULTIPOLYGON, EPSG:4326, and `sci_name`, `sisid`, `presence`, `origin`, `seasonal`
and original attribution/comment/version fields. The DOCX explicitly identifies
map release **2025.2** and its citation. The XLSX is checklist **version 10**,
which is not the map version; its species-name/SIS ID entries were inspected for
kingfisher, great spotted woodpecker, wood pigeon and great hornbill. Neither
source document nor their tabular contents/polygons are added to public Git.

Use on the user's Mac:

1. Download/unpack the newest app branch ZIP (it includes the required folder
   reference in Xcode). Choose this new project in the converter.
2. Download/unpack `Scripts/BirdLife-kaarten-omzetten.zip`.
3. Double-click `Zet-BirdLife-kaarten-om.command`. Choose `BOTW_2025.gpkg`, then
   the project folder containing `BirdingCompanion.xcodeproj`.
4. The launcher prepares an isolated local Python environment and installs
   Shapely 2 (BSD license) using pip. Leave Terminal open while conversion runs.
5. Open/build that same project in Xcode. Private files are automatically copied
   into the app through the blue `PrivateBirdLifeRanges` folder reference.

If macOS blocks double-click, open Terminal, type `bash ` and drag the .command
file into the window, then press Enter. Python 3 (normally available with Xcode)
and internet for the initial Shapely installation are needed. The conversion
itself is offline and reads the original database read-only. No upload is made.

The converter matches exact scientific names, then unambiguous existing aliases,
without changing app IDs. Multiple possible source taxa are not silently unioned
or duplicated across app taxa. Unmatched species stay missing. It streams source
features, preserves all nongeometry attributes/codes, and applies topology-
preserving simplification of 0.01 degrees for compact-map display. That tolerance
is recorded; no new species range is inferred. Holes and disconnected islands
are retained. A broken feature invalidates that species export rather than
showing its remaining features as a complete range. Failed/unmatched items are
listed in the private `conversion-report.json`. Source absence/sensitive omissions
are not filled from observation points or guesses.

Exports are written to a staging folder before replacing the private export.
The prior export is retained as a Git-ignored backup. Failures before activation
leave it untouched. The manifest binds each stable ID to an expected safe
filename and SHA256. Native loading validates metadata, ID and hash. The public
source metadata still says approvedAwaitingFiles; a valid local manifest enables
only the maps actually installed on that Mac. The raw .gpkg and all converted
files/backup/staging files are ignored by Git; only README.txt is tracked in the
empty resource folder. Never put converted polygons in the public helper ZIP.

Rendering uses the verified presence/origin/season definitions: only presence=1
(current extant) and established origins 1,2,3,6 are drawn. The discontinued
presence=2 and possible/uncertain/extinct areas (3–6), vagrants and uncertain
origins are not shown as current range. Exported source attributes preserve
those distinctions. Colors separate resident, breeding, non-breeding, passage
and uncertain season; introduced/assisted origin uses a dashed boundary. Full
citation/terms are available from map info and the existing sources view.

Verification: six portable Python tests pass on fictional GeoPackages, covering
source byte preservation, WKB header/SRS handling, polygon holes, retained
season/presence/origin attributes, output hashes, backups/failure isolation and
ambiguous taxonomy rejection. `bash -n` passes for the launcher; Swift syntax and
Xcode project/resource membership checks pass. New XCTest fixtures check seasonal
classification and exclusion of historical/vagrant areas and unknown codes.
Native XCTest, actual BOTW conversion, native bundling, map bounds/dateline
behavior and comparison against official source maps require the user's Mac.
No successful conversion of the actual 9 GB GeoPackage is claimed here.


## Diagnosing a completed export with a blank map

A converter `Klaar` message confirms files were written to the chosen project,
not that a different project downloaded/opened later includes them. A new public
ZIP necessarily contains only the empty private folder. Copy the completed
`BirdingCompanion/Resources/PrivateBirdLifeRanges` folder from the converted
project into the new one before building, or run the converter for that project.
Do not copy the public README-only folder over an existing completed export.

The map no longer silently discards pending/missing/failed range states. Its
`Kaartcontrole` button reports whether the compiled app includes a manifest,
the number of species, whether the current ID has an entry, whether its file is
included, and whether SHA256 matches. The user can copy this diagnosis without
exporting polygons or absolute simulator paths. Missing data, unsupported current
range and read/decode failure remain distinct. This adds diagnostic visibility;
no root cause on the user's Mac is presumed until the diagnosis or private
`conversion-report.json` has been inspected. The pending-files XCTest fixture now
uses a dedicated empty test bundle instead of depending on the developer's real
installed BirdLife package.


## Converter v2: recover rejected species — 22 November 2026

The user's uploaded conversion report confirms 17,377 input features, 12,901
exported features, 8,987 exported species, 1,557 rejected species and 626 unmatched
source names. Ekster, houtduif, grote bonte specht and ijsvogel are in the rejected
ID list; their application IDs/names resolve correctly. The old report does not
record per-feature reasons, so it cannot prove which validity/code/header check
failed on the actual source. That lack of detail is fixed alongside recovery.

The former converter discarded an entire species on any invalid polygon before
attempting repair. V2 applies GEOS make_valid to invalid polygon geometry,
retains area components and clips them to repaired original exterior shells so
an invalid outside hole cannot become a new range island. Collapsed shell
components without area are counted. If a topology-preserving simplification
fails, a valid unsimplified result is kept. Processing decisions are recorded in
each regenerated feature's appGeometryProcessing foreign member. Presence,
origin, season, IDs and all original nongeometry fields remain unchanged.
Irreparable geometry and unknown codes still prevent a species from being
presented as a complete current range, with exact reason, source row and ID now
in failedFeatures. This is geometric repair, not independent verification of
the source's scientific range accuracy.

Run the updated helper on the SAME project with the existing completed export.
By default it verifies and copies already successful ID/hash-bound maps unchanged
and only reads/decodes geometry for missing species. It still scans source names
read-only; it does not reuse unknown or corrupted files. A source version/size
mismatch aborts instead of silently mixing releases. `--full` explicitly disables
reuse. Metadata/hash format remains compatible with the current app, so no new
app-source ZIP or native code change is required for this repair. The prior
export is backed up atomically. The final message reports reused/added/remaining
species; a remaining failure is not declared fixed.

Ten portable tests pass: the earlier six plus self-crossing repair, rejecting
new islands from outside holes, recovery with byte-identical reuse of a valid
existing map, and specific failure logging while preserving other species.
Actual recovery counts for BOTW_2025 and native rendering are still pending on
the user's Mac; the large source remains unavailable in the cloud.


## Muted map palette — 22 November 2026

All three native MapKit views now share FieldGuideTheme.mapStyle: flat standard
cartography with muted emphasis, no traffic or POIs. This softens Apple's base
map without modifying imagery or introducing a different tile/data provider.
MapKit still controls its exact land/water colors. Range overlays use muted sage,
sand/taupe, slate blue and dusty mauve for resident/breeding/non-breeding/passage.
Fill opacity is 0.24 and boundary strokes are 0.8 points at 0.75 opacity; legend
labels, seasonal distinctions and introduced dashed boundaries remain available.
This is display-only and requires no reconversion of the user's BirdLife files.
Swift syntax/project checks pass; actual native colors and legibility at map
scales/light/dark settings still require simulator/device visual inspection.
