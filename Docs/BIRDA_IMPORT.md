# Birda CSV import

Open Ontdek → tandwiel → Gegevens en back-ups → Importeren uit Birda.
Choose the original UTF-8 CSV in Files, inspect the summary, then tap
**Importeer geschiedenis**. Build/install the updated app first. Merely sharing
a CSV in chat does not alter the app's on-device history.

The export stays on-device; it is not embedded in the application, Git, or a
shared download. Keep your original export and create an external backup after
importing. The local recovery copy protects against a failed import, not against
deleting the app.

## Conversion policy

- Match scientific names and unambiguous scientific aliases to existing stable
  catalog IDs. Reject unknown/ambiguous names with a record number; do not discard
  rows or create guessed species. Source bird IDs and all CSV fields remain in
  optional `importMetadata`, including original counts/lifer flags.
- Use source sighting UUIDs for observations. Preserve every distinct sighting,
  including repeated species in a session. Counts are always 1, per owner choice.
- A source session group with multiple sightings becomes a completed session.
  Its bounds are the earliest/latest exact source instants. Equal timestamps
  produce zero duration; no duration is invented. Untitled singleton groups
  become standalone observations, retaining the original group ID in metadata.
- Original session titles are retained. Untitled sessions and individual logs
  use coordinate labels because this CSV has no place names. A session's map
  coordinate comes from its first observation. Each log retains its own exact
  latitude/longitude, independent of the session representative point.
- Require ISO dates with explicit UTC/offset. Store absolute instants unchanged.
  This export has no timezone identifiers or countries: do not infer these from
  the phone's current location. Imported dates display explicit **UTC** until a
  source timezone is known. Countries are now inferred from bundled offline
  Natural Earth map-unit boundaries. Existing imports are backfilled automatically
  on app launch without importing again. Unresolved coastal/offshore coordinates
  are queried gradually through Apple; unknown/zero coordinates remain unknown.
  See COUNTRY_BACKFILL.md. The user's current phone location is never used to
  label historical observations.
- Preserve imported per-log times/coordinates when editing a session. Explicit
  changes to session start/day shift the logs by that same interval; changing
  other session fields does not collapse logs onto the start time or map point.

## Safety

Import is an additive, revision-checked merge. Existing Birda UUIDs are skipped
without overwriting subsequent edits. A collision with a non-Birda record fails.
Re-importing the same export creates no additional records. A new export with
incompatible bounds for an edited session fails validation instead of replacing
that session. Existing goals and unrelated history remain unchanged.

The store validates the merged archive, creates a local recovery copy of the
previous file, and writes observations/sessions/goals atomically before
publishing any in-memory changes. A failed save leaves the current store and
revision untouched. Import is unavailable during a live session, an unreadable
history, or a backup operation. Automatic external backup scheduling follows the
normal store revision change, if configured.

Parser: RFC 4180 commas/quotes, escaped quotes, embedded newlines, UTF-8 BOM,
CRLF/LF. Reject malformed quoting, duplicate IDs/headers, invalid coordinates,
missing columns, conflicting session titles, missing timezone offsets and unknown
species. Maximum 16 MiB / 100,000 observations.

## Verification

Synthetic XCTest cases in `BirdaImportTests` cover parser edge cases, aliases,
UTC/offset equivalence, count policy, grouping/min-max/zero duration, repeated
species, ID conflicts, stale previews, repeat imports preserving edits/goals,
persistence round trips, recovery copies and failed writes. No private CSV rows
are test fixtures.

Linux verification: Swift tree-sitter syntax parse and OpenStep project parse,
`git diff --check`, independent Python audit of the supplied CSV against the
catalog. These checks do **not** execute the Swift parser or XCTest. Xcode build,
XCTest and device import/file-picker verification still need to run on macOS.
