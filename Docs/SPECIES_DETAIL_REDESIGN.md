# Species detail redesign — 22 November 2026

The user's two supplied before/after comparisons (kingfisher and great hornbill)
replace the previous species-page layout. This implementation targets the right
panels; pixel matching has not been verified without Xcode.

- A shared fixed header places English then Dutch names higher. The Dutch
  Fraunces title uses 1.02-em paragraph line height and retains -2% tracking.
  Log status stays below the add action. Existing round actions remain available.
- Overzicht, Informatie, Waarnemingen share an outlined ivory strip below the
  heading, with a light beige rounded active segment. Visual border is 34 points
  high while buttons retain 44-point touch targets. At accessibility sizes the
  strip stacks vertically instead of truncating labels.
- Overview contains only the large artwork viewport, with no bio, span or
  habitat footer and no vertical scrolling/dots. Images align to its bottom,
  extend 18% beyond the viewport width and may bleed at horizontal screen edges.
  Empty alpha margins are trimmed in a cached display image; source originals
  and artwork manifest remain untouched. Unsupported pixel layouts use the full
  original. Composition and anatomy are not regenerated or changed.
- Informatie contains span and bio, a 220-point interactive range map, and the
  habitat footer pinned above the shared navigation. Text/map content scrolls.
- Waarnemingen retains the existing observation history and map-opening flow.
- UIPageViewController supplies four hosted SwiftUI slides in a circular order:
  dynamic, front, rear, ventral flight, then dynamic again. Backwards wraps too.
  No page-control data source is implemented, so there are no navigation dots.
  The current page is retained across tab changes. Accessibility labels name
  the view, species and slide number.

## Verification

Run tree-sitter Swift syntax parsing, project parsing and `git diff --check` in
cloud. Added XCTest coverage for all four slide roles, repeated forward loops,
reverse boundary and empty input. Xcode/unit/UI execution is unavailable here.

On Mac compare kingfisher and great hornbill at the reference device size:
header/title baselines and line breaks, outlined strip, edge bleed, bottom artwork
alignment, swipe 4→1 and 1→4 (including cancelled gestures), tab changes retaining
the page, information scrolling/map interaction, missing-art placeholders, and
small screens/Dynamic Type/VoiceOver. Exact typography, crop, safe-area behavior
and UIKit/SwiftUI integration require native validation; no screenshot preview
or simulator result is claimed.


## Screenshot corrections — 22 November 2026

- UIKit initially used the variable font file's default weight 900, whereas the
  original SwiftUI SerifText explicitly used regular. The title now explicitly
  selects the wght axis at 400, keeping tight baseline spacing and -2% tracking.
  A 4-point visual offset lowers only the Dutch title without changing header
  layout or tabstrip position.
- Bio base size is 12.8 instead of 16 points (20% smaller), still light and scaled
  with Dynamic Type. Span size remains unchanged.
- Artwork dimensions now use an explicit aspect-preserving fit above a 32-point
  clearance for the central navigation button. Only dynamic heroes bleed
  horizontally; front/rear/flight fit their full width. The habitat footer uses
  the same full-composition fit with explicit height and clearance.
- The map's empty padded overlay no longer produces a blank ivory dot.
- BirdLife remains approvedAwaitingFiles: there is no range archive, shapefile
  or species GeoJSON in this checkout. Retrying the approved archive HEAD request
  still failed at the network proxy with tunnel HTTP 403. No polygons or source
  metadata were invented or replaced with an occurrence map. Range rendering
  remains blocked until the authorized files can be supplied for conversion.

Added native XCTest coverage for regular variable-font weight and fitted
portrait/flight/habitat bounds. Cloud checks cover syntax and project structure,
not UIKit typography, cropped-image positioning or MapKit. Mac build/tests and
comparison of the revised screenshots remain required.

## Navigation refinement — 22 November 2026

Central action diameter and plus/close glyph dimensions reduced by 10%; the
circle is now 57.6 points instead of 64, still above the 44-point touch minimum.
Its center remains at the navigation's white top edge. Navigation paths now all
use FieldGuideTheme.navigationStroke (0.7 points, round caps/joins), including
plus/close and live play. The former SF Symbols for binoculars, identification,
clock and bird are replaced by vector outlines to avoid glyph-dependent stroke
weights; goal circles/lines and globe use that same stroke. Shape geometry
scales before stroking, preserving one physical line width at different sizes.
The goal completion dot remains filled. Static syntax and diff checks pass;
visual matching to the binocular reference and native rendering need Xcode.

### Repeated low/clipped artwork in simulator screenshots

The header was previously supplied via safeAreaInset while the hosted pager
ignored inherited safe areas. A larger bottom margin alone did not establish
an actual smaller UIKit viewport. The header is now a real VStack sibling above
the carousel, whose controller receives explicit bounds from the remaining
GeometryReader. Supplemental front/rear/flight views center inside that viewport;
only the dynamic hero remains bottom aligned. Page-scroll automatic content
insets are disabled. Verify these changes on Mac with the supplied woodpecker
flight and long-tailed magpie examples; cloud syntax checking is insufficient
to prove that UIKit clipping has been resolved on a device.


### Further navigation/artwork refinement

Binoculars and logbook bird outlines are 10% larger (24.2352 and 23.76 points),
using the same unscaled 0.7-point stroke. Only the dynamic/detail first slide gets
a 10-point leftwards display offset to leave more room at its right-facing head;
front/rear/flight positioning is unchanged. Native visual verification pending.

### Information tab: map first and full-screen expansion

Information content now puts the compact distribution map before span and bio.
The habitat footer uses a width of 112% of the viewport; its layout derives the
height from the scene aspect ratio and retains navigation clearance, clipping
only the side bleed. It no longer shrinks to fit a fixed 160-point box.

A tap on the compact map or its explicit 44-point expand control opens a native
fullScreenCover containing the same interactive distribution-map component and
muted seasonal styling. A safe-area-positioned 44-point close button dismisses
back to the Information tab. The full-screen map omits the compass at the close
button's position and still supports pan, zoom and rotation. Existing source/
diagnostic controls remain separate from the map tap gesture. No range data,
conversion or taxonomy changes are involved.

Swift syntax, Xcode project parsing and whitespace checks pass in cloud. Verify
compact-map taps versus pan/zoom/source/diagnostic buttons, full-screen safe
areas, close/return, and wider habitat geometry on Mac. Native interaction or
visual correctness has not been claimed from syntax checks.


### Faster Information revisit and compact map credit

Range I/O, hash checks and typed JSON/coordinate processing now run on a separate
actor, with prefetch from the species page and bounded snapshot/render caches.
Information and full-screen map share the prepared data. The BirdLife credit is
small text at the upper left without a background; diagnostic/status panels are
separate. First/dynamic illustration shifted an additional 10 points left, for
-20 total. The other three slides are unchanged. Native timings and visual
verification remain pending; no new GIS conversion is required.

### Map, observation and artwork refinements — 22 November 2026

- Apple Maps retained following the user's explicit choice; no Google SDK,
  API key or billing dependency added. Range maps use saturation 0.22 on the
  map layer (including polygons). MapKit does not expose a separate ocean-color
  token. Controls/legend remain outside this effect. Legend has a lighter
  near-white background, horizontal margins and bottom padding inside the safe
  viewport. Only the map canvas ignores safe areas in full-screen views.
- Observation selection presents a true fullScreenCover above root navigation.
  Closing uses a dedicated upper-right round button; root + never becomes an
  observation-close control. The beige details card sits at the bottom inside
  safe areas, with custom outlined location/edit marks. Marker artwork is
  fitted into 48 points with 12-point padding on each side.
- Observation lists show the numeric total alone (VoiceOver retains its label)
  and subtle separators between records. Add/edit observation uses the exact
  shared species-page back button in a custom header, without a system glass
  toolbar. Date/time sit side by side, with a vertical accessibility fallback
  only when the controls do not fit. Selected-bird artwork has no added tile.
- Dynamic hero is an additional 30 points higher; the other three roles retain
  their position and the previous -20-point hero horizontal offset remains.
- Source woodpecker dynamic and habitat atlas images contain opaque paper.
  Display compositing replaces edge-connected near-paper pixels with the app's
  sRGB ivory. Enclosed pale regions and source alpha are retained; original
  artwork/manifest hashes are unchanged. Coordinate/image preparation stays
  local; the pixel traversal runs in a detached task using Sendable byte arrays,
  and finished UIKit images are cached on the main actor. No original artwork
  is regenerated. A fixture protects enclosed white, dark detail and alpha.
- Country flags use 257 flat local flag-icons v7.5.0 assets, cropped to squares
  and circle-masked in one shared component. Emoji/waving flags are no longer
  rendered in country or observation lists. MIT notice is included in the
  already-bundled SpeciesDetails-NOTICE.txt and source information view.

Cloud checks: Swift syntax parsing (40 files including XCTest source), Xcode
project/resource parsing, flag catalog/PNG validation and git diff --check.
No Xcode compiler, XCTest execution, simulator visuals, audio playback or device
performance measurement is available here. Verify the safe corners, map/source
controls, close/edit/return flow, Dutch date control widths, paper-compositing
edges and white plumage/bark, first-slide crop, flags and audio on Mac. Existing
private BirdLife files do not need reconversion and must be retained on updates.
