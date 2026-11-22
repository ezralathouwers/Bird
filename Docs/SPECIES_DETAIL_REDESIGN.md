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
