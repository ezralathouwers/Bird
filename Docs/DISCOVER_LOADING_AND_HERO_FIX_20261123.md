# Discovery loading and dynamic artwork — 23 November 2026

The combined discovery repository previously waited for both providers before
publishing anything. Observation.org required sequential pagination across three
date windows, with a separate DateFormatter created for every matching record.
This code path can leave the first screen loading even when eBird has finished.
The reported iPhone hang itself was not reproduced in this Linux environment.

The repository now publishes each first successful, complete source immediately.
The view model ranks/displays those rows and clears the blocking loading state,
then accepts the combined chronologically ordered feed when the other source
finishes. Each provider has a 20-second total budget; the losing timeout/request
tasks are cancelled. URLSession and provider pagination cooperate with task
cancellation. One failed provider keeps the other's data and shows a notice;
two failures end loading with an error and retry controls.

Observation.org fetches its three independent date windows concurrently, with
at most ten pages per window and an eight-second per-request timeout. A failed
or truncated window still rejects that provider rather than claiming complete
coverage. Dates are parsed once per distinct day. Existing five-minute cache,
radius/30-day filtering, species matching, source links and credits are retained.

The gear glyph moves another 8 pt towards info inside its existing 44 pt hit
target. Add menu top clearance increases from 24 to 39 pt.

Torenvalk, roek and merel dynamic images were individually inspected. Alpha
bounding-box measurements found faint pixels extending far beyond the visible
composition (for example kestrel alpha >0 bounds 41,20–1512,992 versus alpha >8
bounds 198,130–1337,908). Display-only trimming now ignores alpha <=8 for these
three dynamic assets, retaining a 24-pixel margin. Their target magnifications
are 1.9, 1.45 and 1.4, with proportional vertical fitting on short screens. The
compositions center higher in the available viewport and may extend beyond both
horizontal edges. Other images and the original artwork/hash manifests are
unchanged; no illustration generation was resumed.

Validation:

- All 42 app/test Swift files passed tree-sitter syntax parsing.
- `git diff --check` passed.
- Catalog visibility Python tests: 3 passed.
- Added XCTest regressions: first source must reach the consumer before a gated
  second source can finish; stalled sources must clear the view model's loading
  state; enlarged dynamics preserve vertical clearance/aspect ratio and leave
  non-dynamic fitting unchanged.
- Native compilation, XCTest execution and iPhone visual/timing verification
  remain pending: this environment has no Swift compiler or Xcode.
