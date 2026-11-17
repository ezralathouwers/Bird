# Ontdek homepage

The app now starts on the binoculars page with “Vandaag in …”, the current-location name, three icon-only filters, and a lazy scrollable bird list. Returning through binoculars clears the guide navigation path and returns home. The default search radius is 10 km. Location permission is requested only on use; denial, loading and place-name failure are visible. No user GPS coordinates are persisted by this page.

Rows show the Dutch name, the primary-illustration asset and a logged/not-logged eye. Filters are all (grid), logged (eye with pupil) and not logged (empty eye). They read published personal observations live; a record save changes the badge and current filter automatically. Store load failures produce unknown badges and disable the two status-specific filters rather than pretending records do not exist. Row taps open the selected species; logging/maps use its stable ID. New six-species illustrations are generated pilot assets pending anatomy/user approval.

## Ranking definition

“Most seen” is implemented as the number of **distinct reporting checklists per species** in a rolling 30×24-hour window, inside a 25-km geodesic radius. It does not count individual birds, rows duplicated on one checklist, or your personal records. Future/out-of-window/out-of-radius/invalid reports are excluded. Ties are deterministic by Dutch name then ID. All filters preserve ranked order. This is reporting effort, not a calibrated encounter probability or a guarantee of presence today. Unreported species may still occur.

The provider protocol supplies the complete requested window and attribution. Incomplete feeds are rejected rather than advertised as a valid frequency ranking. App-local IDs and mock taxonomy are retained; an eventual eBird ID crosswalk must be explicit.

## Verified eBird limitation and remaining dependency

Reviewed 17 November 2026:

- Official API documentation: https://documenter.getpostman.com/view/664302/S1ENwy59?version=latest
- The public Postman collection backing those docs was read at https://documenter.gw.postman.com/api/collections/664302/S1ENwy59?segregateAuth=true&versionTag=latest . Its Recent nearby observations endpoint reports only the most recent observation per species. Available sorts are date/species, not frequency; it supports back=30 and up to 50 km, with API authentication.
- Official data products: https://science.ebird.org/en/use-ebird-data/download-ebird-data-products
- Official frequency explanation: https://support.ebird.org/en/support/solutions/articles/48001255130-ebird-bar-charts-and-graphs . Bar-chart frequency uses complete-checklist reporting fractions, not raw individual-bird totals.

Consequently the recent-observations API alone cannot provide the requested complete 30-day frequency ranking. EBD/checklist access or an authorized equivalent aggregate provider is still needed. The EBD is a requested, periodically updated dataset, not an assumed real-time endpoint. No API key, authenticated data, external sightings or production taxonomy was added. No third-party data was scraped. The default repository honestly reports unavailable local data.

“Bekijk voorbeeldpagina” explicitly enables six fictional species/counts and remains usable offline. A demo without GPS says Voorbeeldlocatie; with GPS, an unmistakable banner says its rows are not live reports for that location. Demo selection never adds observations, never makes species appear logged and never alters the lifelist. The dataset can be replaced by an authorized provider through DiscoverRepository; do not implement the live adapter against latest-only records or claim all potentially present species are known.

## Mac checks

1. Launch and confirm Ontdek is the initial route, not the kingfisher.
2. Simulate current location, denied permission and no network; verify heading and state messages.
3. Open the explicit demo. Verify counts 12/10/8/6/4/2, order, lazy scroll and 44-point filters.
4. Open a species and log it. Return; its eye and both filters must update without reload. Restart and repeat.
5. Test an empty filter and store-load error. Tap binoculars from detail to return home.
6. Open several species; ensure artwork, form ID, Google query, map and logs refer to that species, never reused kingfisher content. Unreviewed species text is explicitly unavailable.
7. Test plus from the homepage: select a species first. From species detail it may use the current species. Verify saved records appear under Logboek.
8. Run the new ranking/filter/view-model tests in Xcode, then integrate and test an authorized complete live feed before treating the ranking as real.


## Discover layout refinement
The heading moves down 60 points, grows from 34 to 44.2 points (+30%), and gains 6 points below. The time-window subtitle and per-species report counts are hidden; the existing 30-day ranking remains unchanged. Species names use Fraunces, illustrations shrink from 104 to 72.8 points, and subtle rules separate rows. Only discovery-row status badges shrink from 44 to 22 points; filter controls and species-page badges retain their sizes. Both GPS and explicit demo queries use a 10 km radius. Native layout, Dynamic Type and rendering still require Xcode verification.
