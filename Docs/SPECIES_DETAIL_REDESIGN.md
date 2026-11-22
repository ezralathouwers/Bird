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

### Footer recovery and consistent forms/lists — 22 November 2026

The footer now renders a synchronous cached source panel immediately, giving the
safe-area inset its actual image geometry before asynchronous paper compositing
finishes. Previously its initial empty Group could have no layout footprint.
The processed panel replaces that source in place; a regression fixture checks
all 33 source panels are available before async preparation. Native layout must
still be verified on Mac. Dynamic heroes move another 30 points upward (-60
total vertical offset); other roles are unchanged. AGENTS.md now requires future
dynamic art/props to end naturally or fade at the upper edge, without sharp cuts.

Range season colors now use distinct green/orange/blue/purple with 0.38 fill,
and overall map saturation is raised to 0.72 so seasonal distinctions survive.
The basemap remains muted, although MapKit has no separate ocean-color token.
Expand control is upper right; full-screen has an adjacent 44-point padded
classic-bird badge. Legends leave clearance above Apple's attribution as well as
safe corners. Apple Maps legal attribution remains in its standard presentation:
MapKit exposes no public API to split/reduce those native links, and Apple Maps
terms prohibit removing/obscuring/altering legal notices/hyperlinks.
References: https://developer.apple.com/documentation/mapkit/mkmapview and
https://www.apple.com/legal/internet-services/maps/terms-en.html (section 1.3).

Add/edit observation uses a centered custom header, a smaller 84×100 bird with
26-point Dutch name, reduced top/row spacing and rounded date/time buttons that
open native wheel pickers. The shared radius is 18 points for search/location/
name/date/time controls and primary actions in observation, session, goals and
photo ID flows. Session editing retains date/time constraints and record edits.
The place picker uses an outlined dark circle, without a visible annotation
caption. The saved-observation detail location mark has fixed wider geometry.

Logbook and country detail share the same translucent 60-point count as species
observation totals, with the sort menu aligned at the upper right. Country detail
has the shared species-page back button and a centered small flag/name header.
Family strips have reduced padding/spacing; export buttons are hidden here while
the underlying export capability remains intact. Observation count bottom padding
is reduced. Countries have 33.6-point flags (30% smaller) and tighter rows. ID,
sessions, goals and countries use exactly Discover's PageHeading renderer, while
keeping their existing top padding/layout anchors.

Available verification: 40 Swift syntax trees, project/source membership checks,
git diff --check, local source/panel metadata checks and public audio API/media
requests. Added XCTest is not executed here. Required Mac checks: footer mounting
and color-compositing replacement, long hornbill names, date/time editing and
session day limits, safe full-screen controls/legend, live season colors, count/
sort headers, Dynamic Type, and reference-audio looping. No new BirdLife export.

### Birder and checklist favorites — 22 November 2026

Home-screen name becomes Birder, with an opaque universal 1024-point app icon
using the exact original navigation bird outline and ivory/charcoal tokens.
Target/scheme, bundle ID, keychain service and local storage paths stay unchanged.

The dynamic hero is now x=-50/y=-30: another 30 left and 30 down from the preceding
revision. Other slides retain their positions. Great spotted woodpecker dynamic
art v2 is an image-generation edit of the original, with transparent paper and a
softly fading upper trunk. The transparent original and ivory composite were
visually reviewed at full resolution; one head/beak, two feet, one visible folded
wing with far wing naturally occluded, and full tail/framing were checked. The
manifest binds the anatomy review to its SHA-256 and retains the previous hash.
Classic/front/rear/flight remain unchanged. App placeholders show the bird icon
alone; missing-image accessibility descriptions remain.

Seasonal range colors are now duller green/ochre/blue/mauve; fill and stroke
contrast are retained. Compact legend bottom inset changes 32→24, but does not
cover the required Apple legal links. Full-screen legal clearance is unchanged.
Country flags use saturation 0.82 throughout; Countries heading gets 10 more
points below it. Observation date/time gap is 8, location heading has 8 more
points above it, and the map height is 228 (5% shorter). Detail-card edit moves
6 points up/right; the location glyph is 24×24, shifted 2 points left/up, and
its entire text/glyph row has 5 extra points above it.

Goals and sessions no longer show export buttons. Goals have beige cards with a
right-aligned full-height dynamic favorite image, or icon-only fallback if that
role has no asset. Long press selects one favorite and automatically includes the
species; selecting another favorite replaces only the favorite, and deselecting
it clears the favorite. A rounded custom star sits left of the selection circle.
A named VoiceOver action offers the same operation without a long press.

Goal add/edit shares ObservationForm's centered custom header. Detail uses the
same species back button and round pencil action, less row padding, and the same
progress view as the cards with 30 points below it. Editing updates the existing
record transactionally; ID/createdAt, other goals, observations and sessions are
preserved. Unknown selected IDs are retained on edit. Optional favoriteSpeciesID
keeps older goal JSON readable; invalid favorites outside the selection are
rejected. Tests added for selection transitions, legacy decode, archive/favorite
round trips, identity/date preservation and rejected/failed updates.

Cloud verification: Swift syntax trees/project references, git diff --check,
opaque app-icon pixel size/catalog settings and exact reviewed-asset hash/alpha.
Native XCTest/build, app-icon installation, long-press vs tap/scroll behavior,
card image cropping, edit/save/return and final layout/colors require Xcode.
No BirdLife reconversion is needed.

### Session flow, lifers and latest spacing — 22 November 2026

Compact Information range map hides its seasonal legend; full-screen keeps it.
Shared location outline has a curved bottom, and goal/session edit actions use
the exact outlined pencil geometry from observation details. Goal cards have
28-point vertical padding, lighter beige and 18-point gaps. Flags use saturation
0.72. Discover's magnifier is now a vector circle and handle stroked together at
the same 0.7-point width. Discover (both list modes), Logbook, Sessions and Goals
scroll content gain 50 points of bottom padding (24→74).

Session changes supersede earlier always-confirm-finish behavior:
- Add menu's Session action starts a live session. Live back/header matches the
  species screen, with reduced timer top space. Search opens a full-screen picker
  with a fixed header/search bar, nearby-ranked empty-query suggestions and
  world catalog text search. The same picker is used from review/add/edit.
- Session rows show classic artwork, Dutch/English names and dividers; live/detail
  retain time without per-row location. Live permits deleting a stored log and
  adding its species again. The store/logger/pickers reject additional entries
  of an already logged species in that active session. Success toast is removed;
  real location/write failures remain visible.
- Final review has date/start/end on one row (horizontal scrolling fallback on
  small/accessibility sizes), no current-location button, a 24-point count and
  compact removable artwork rows without individual date/time fields. Existing
  GPS/time values survive review; changing start/day shifts the live timestamps.
  Retrospective session edits update their logs to the revised session location/
  start. Finish commits directly, then returns to Sessions through a root callback.
- Completed session detail is a navigation destination rather than a sheet. It
  has the shared back/edit header, location title and date/start/end, a translucent
  numeric total and latest/alphabetical sort menu. Completed edits use an optimistic
  expected-log snapshot and preserve every other session, goal and observation.
- Overview uses tighter row padding, date + compact duration (e.g. 2u14), count and
  lifers when nonzero. Active banner has more horizontal padding. Lifers derive
  from each species' earliest retained global observation, with a stable UUID
  tie-break so only one tied observation qualifies. The shared sparkle mark sits
  left of the time on live/detail rows. Historic imported duplicate species are
  not discarded or rejected on load; review cannot increase their multiplicity.

Meaningful XCTest additions: uniqueness/delete/re-add, lifer chronology/ties,
compact duration and both sorts, completed editing/reload/stale review protection.
The old test that intentionally logged a live species twice now expects rejection
and logs a different species to check time/location preservation. Native build,
XCTest, navigation/modal transitions, long lists, keyboard, live GPS, end-time
validation and actual card/map rendering remain unverified without Xcode.

### Confirmation, centered detail headers and Identification sizing

Session lifers now use one custom four-point outline star rather than the
three-star SF Symbol. Draft review computes lifers from all other retained logs
plus its current edited logs, so removed/added/date-shifted rows get the correct
status before save. The star remains visible when review hides individual times.
Live time, lifer and remove button share a four-point-gap trailing group; review
search bottom spacing is reduced by 12. Overview uses `1 lifer`, otherwise
`x lifers` (and omits zero).

Review presentation now retains an explicit BirdSession item instead of deriving
its content from activeSession after saving. Saving clears activeSession; that
previously could remove modal content before completion/dismiss callbacks ran.
The stable item remains until onSaved clears it, then onDismiss routes to Sessions.
This structural correction still requires a native navigation test.

Sessie and Doelstelling detail headers use one shared centered title with the
existing back/edit controls at the original margins. Identification uses explicit
layout measurement: heading stays at its existing top anchor; title-to-card gap
is 18 points, matching Goals. Foto and Audio cards equally fill remaining height,
with 24 points between them. At large text/small heights they retain minimum
148-point cards and scroll. The camera is a custom outline without a flash dot.

Countries now sort by descending total observation count, independently of the
unique-species count still displayed. Country counts normalize ISO codes and
exclude unknown country values; ties use localized Dutch country name and code.
A regression fixture covers repeated observations vs more unique species and
input-order independence.

Verification available in cloud: Swift syntax/project/source-membership and
whitespace checks, plus pinned model schema inspection. XCTest, recognition of
recordings, native review/dismiss/navigation, camera/star visuals and card sizes
remain unverified without Xcode. No private BirdLife files need reconversion.


### iPhone feedback revision — 22 November 2026

The app fixes its light appearance at the root and in Info.plist. Shared search
fields explicitly set charcoal text and a readable placeholder, including
fullscreen pickers. The add-observation picker uses the custom centered header.
Species tabs and the Information map move up slightly; the bio sits closer to
the wingspan and fades over its final 22 visible points when clipped by the
information viewport. It remains fully scrollable; map attribution is unmasked.

Location requests now share one short-lived CLLocationManager and accept a
recent fix only within the requesting screen's age/accuracy bounds: Discover
60 seconds/500 metres, observation form 30 seconds/150 metres, live session
15 seconds/100 metres. Concurrent requests coalesce; hardware stops when none
remain. Requests time out after 10 seconds (15 for live logging). Place naming
caches successful nearby results for 30 minutes within 75 metres, coalesces
concurrent lookups, and bounds new geocoding to three seconds. Cold GPS fixes
and denied/approximate permissions can still require a manual map selection.
No real hardware latency measurements were possible here.

Discover removes the demo-page action and softens/compacts local settings.
For never-logged species, the separate log badge opens an actual eBird
checklist from the displayed results; bird image/name still open the species
page. Only valid S-number checklist IDs become links. When none is provided,
the badge stays static. No speculative observation links are constructed.

Lifers use a larger filled rounded four-point star, further from the time.
Identification cards have a smaller gap, closer subtitles and more bottom
clearance. Goal selection opens a fullscreen search with back control and
retains multiselection/long-press favorite selection. Goal artwork keeps its
left fade but has full base opacity; progress takes half the content width.
Family display labels use Dutch common names where mapped and checklist
English common names otherwise, preserving every family/species ID.

Verification: Swift syntax trees, project source references, Info.plist and
whitespace can be checked in cloud. XCTest and native iOS builds/device visual
and performance checks remain unverified. No BirdLife reconversion is required.


### Launch and add-menu motion — 22 November 2026

A one-second foreground Birder bird-outline logo on olive appears before the
Discover view is revealed. Discover is mounted underneath; the shared location
service prewarms concurrently only when already authorized. The intro never
waits for a GPS fix. The add menu uses a fast circular mask expanding from the
measured plus-button center while the prior page stays underneath. Reduce Motion
uses a fade instead. Native safe-area positioning and animation smoothness need
review on an iPhone; no screenshot or performance claim was generated in Linux.

Discover lists now include a further 20 points of bottom padding (94 total).


Swift 6 build follow-up: CircularMenuReveal now explicitly marks its plain
CGFloat progress storage and animatableData accessor nonisolated, satisfying
Animatable's nonisolated requirement without relaxing concurrency checks. The
SwiftUI body remains actor isolated. Syntax/whitespace checked in Linux; Xcode
compilation is still required to confirm against the user's SDK.


### Scroll fade and concentric add reveal follow-up

Information content measures its actual scroll offset. A subtle top ivory fade
appears only after scrolling, reaching full strength over 16 points; it is fully
transparent at rest. The add menu and its mask now share full-screen bounds,
with button/mask geometry both measured in global coordinates. The mask no
longer independently expands into safe areas, avoiding a shifted circle center.
A geometry fixture checks center invariance and corner coverage across multiple
safe-area frames and animation stages. Syntax/project checks can run in cloud;
Xcode compilation, actual scroll rendering and animation smoothness still need
physical-iPhone review.


### Native launch handoff and flight — 22 November 2026

Info.plist now defines UILaunchScreen using LaunchOlive and LaunchBird assets;
the default empty launch-screen generation flag is removed from both app build
configurations. The native launch and SwiftUI overlay share the same sRGB color
and 88-point transparent bird artwork (1x/2x/3x), centered in full-screen bounds.
This replaces the default neutral screen before the olive logo. Once SwiftUI
appears, the logo is held for 750 ms then flies diagonally upward/right for
750 ms while the olive background fades away. Reduce Motion uses only a fade.
Location prewarming runs concurrently and does not delay the intro. PNG assets
were visually inspected; plist, project, image scales and Swift syntax checked
in cloud. Actual launch-screen rendering/handoff and animation need Xcode and
an iPhone cold-launch test; no native build was available here.
