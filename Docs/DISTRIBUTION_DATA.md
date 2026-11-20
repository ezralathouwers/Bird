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
