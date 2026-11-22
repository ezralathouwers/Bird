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
