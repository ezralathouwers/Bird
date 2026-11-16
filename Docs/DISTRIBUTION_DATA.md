# Distribution map data

The Verspreiding tab is a native interactive MapKit map. It replaces the scrollable artwork layout, puts the tabstrip below the heading, and fills the remaining space above navigation. Overview keeps the artwork. MapKit base tiles can require network and aren't guaranteed offline; NWPathMonitor provides an offline message. This is a distribution overlay, never a claim of current bird presence.

No verified kingfisher distribution dataset was supplied. Consequently **no scientific area is bundled or drawn**. The app explicitly reports unavailable range data while keeping map gestures usable. Do not replace this with an unlabelled hand-drawn approximate range or occurrence-density layer.

To supply a dataset, obtain a licensed, scientifically reviewed WGS84 GeoJSON FeatureCollection. Use Polygon or MultiPolygon geometries, with top-level nonempty `source`, `license`, and `version` strings (GeoJSON foreign members). Name the file `sample-alcedo-atthis-range.geojson` for the current mock ID and add it to the app Copy Bundle Resources phase. Before production, align stable IDs and taxonomy versions. Preserve source attribution, seasonal/presence semantics and review status; the current single-style renderer does not distinguish seasonal ranges.

The loader rejects missing provenance, non-area geometry and empty collections. Polygon holes and multipolygons are handled through MapKit's decoder; the camera fits the loaded geometry. Provider implementations can replace the bundled repository without changing the map UI. There is no automatic download, paid provider, taxonomy change or new credentials.

Mac checks: load a known licensed fixture, confirm outline and holes align with the basemap, verify pan/pinch/rotate and compass, source attribution, offline/missing/malformed states, tab switching and restored overview, full-height layout on short iPhones and large Dynamic Type. Large datasets may require simplification and asynchronous decoding before production; current local decoding is synchronous.
