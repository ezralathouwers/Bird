# eBird nearby species integration — 22 November 2026

The unavailable message came from `UnconfiguredDiscoverRepository`, not GPS.
The production DiscoverViewModel now defaults to EBirdDiscoverRepository, also
used by the session species picker. Explicit demo data remains opt-in.

## Provider contract

Official documentation: https://documenter.getpostman.com/view/664302/S1ENwy59
Key request: https://ebird.org/api/keygen

GET `https://api.ebird.org/v2/data/obs/geo/recent` with lat/lng, dist=5,
back=30, sort=date, cat=species, includeProvisional=false, maxResults=10000. The personal
key is sent only in the X-eBirdApiToken HTTPS header. The transport uses an
ephemeral session with no disk/URL cache. Error bodies and keys are not logged.
No observation upload or sharing is introduced.

This endpoint returns the most recent observation per species, not all
checklists or reporting frequency. The app preserves
server `sort=date` order (latest reported first), including same-day sightings.
The local date parser is only a day-window validator; it is never used to
re-sort observations with unknown timezones or date-only timestamps. Radius
and unknown-taxon filtering preserve the remaining response order. This keeps
these inventories out of the complete-checklist frequency sort. A response at
the 10,000-row cap is rejected as incomplete. Current-day queries only; the API
cannot supply a historical thirty-day window for an old session. API dates have
no timezone, so the inventory uses day granularity rather than asserting an
exact observation timestamp; those derived dates are never saved as user logs.
Local validation additionally filters radius, dates and duplicate checklist IDs.

Species are resolved by the bundled eBird code, with unambiguous scientific
name/alias fallback. Existing IDs and sample artwork references are preserved.
Unmapped taxa are skipped, and a wholly unmappable response is an error. Empty
API results are a successful empty state. Missing/invalid key opens connection
controls; throttling, network failures and malformed responses offer retry.
Changing/removing credentials invalidates old requests and clears old results.

## Credential flow

Discover → Verbind eBird / Instellingen lokale meldingen. Secure input, validated
against eBird before Keychain replacement. `WhenUnlockedThisDeviceOnly` means
no CloudKit/iCloud Keychain synchronization. Cancelled validation never saves
the draft; a failed replacement does not delete the previous working key.
The user can explicitly remove the credential. No key is bundled in the app or
committed. The key must be entered once on each simulator/device.

## Verification and remaining Mac checks

- Live authenticated HTTPS request: HTTP 200, 92 species near Gent at the time
  of the check; all 92 resolve to stable catalog IDs. Personal key excluded from
  documentation, fixtures and source control.
- Swift tree-sitter syntax parsing and Xcode project structure/membership checks
  are available in the cloud; they do not type-check Apple SDK calls.
- XCTest cases added in Phase1Tests.swift for request parameters/header safety,
  UUID-style keys, input validation, stable IDs/aliases, 5 km radius and provider recency
  ordering, authentication/rate-limit/network/malformed errors, cancellation,
  empty results and unsupported historical dates. The former missing-provider
  test now explicitly injects UnconfiguredDiscoverRepository so it never depends
  on a developer's Keychain or network access.
- Xcode is unavailable here: run the shared BirdingCompanion scheme tests on a
  simulator. Verify first-use/save/relaunch, invalid replacement, cancellation,
  disconnect, revoked key, offline/retry and location changes. Verify that logs
  and illustration links open under the same IDs and that session pickers load.
- Follow-up live HTTPS check: HTTP 200, 72 species within 5 km of Gent,
  `back=30&sort=date`; returned observation dates are descending.
- Follow-up on 22 November: changed the shared local radius from 10 to 5 km
  (Discover, connection probe and session picker); switched from alphabetic
  ordering to latest reported first. Regression fixtures cover ordering against
  both alphabetical order and counts, duplicates, out-of-radius/outdated/future
  records and explicit `dist=5`, `back=30`, `sort=date` request parameters.
- On an actual iPhone verify location permission and Keychain persistence. No
  native build, Keychain integration or simulator/UI test is claimed by this work.


### Checklist language links — 22 November 2026

Checklist links explicitly request Dutch using `siteLanguage=nl&locale=nl`.
This does not change the user's ChatGPT, Safari or eBird account settings. Both
parameters are attached only after strict validation of a provider checklist ID.
The eBird website served an anti-bot interstitial from this cloud workspace;
end-to-end language rendering must be checked in the user's browser. An existing
eBird login/cookie preference may still need changing on eBird itself.
