# Birding sessions

## Behaviour

The clock destination lists completed sessions descending by start date. Session name equals its mandatory location name. Two 44-point round actions add a completed session (clock) or start a live session (play). An active-session card reopens the live screen; only one live session may exist. Session details show linked individual observations.

Completed-session entry reuses the observation map/location picker: initial current location, reverse-geocoded editable place name, mandatory coordinate, automatic country. One day picker and separate start/end time fields allow past sessions, including overnight sessions (end earlier than start means the following day). A searchable catalog list supports Dutch, English and scientific names; selection is one observation per selected species. All retrospective observations use the session start time and session location. The catalog currently contains six sample species, not a production worldwide catalog.

Live sessions store their start time immediately. The 72-point central navigation action becomes an ivory play glyph on khaki on every root destination, including observation maps, and opens the live screen. Other navigation remains usable. The live screen includes elapsed time derived from the saved start date, bird search/add buttons, newest-first saved observation rows, an observation total, and finish action that opens an editable review form, followed by mandatory confirmation. Repeated logs of a species are retained as separate observations. Finish is disabled while a log is being located/saved. Leaving the live screen does not finish the session. After relaunch the saved active session remains accessible through the play action.

Every live log captures the button-tap time and requests a fresh foreground GPS fix (no continuous or background tracking). Fixes more than 20 seconds from the tap are rejected. Reverse geocoding supplies a place label/country; if it fails, the actual coordinate becomes the label rather than reusing the session location. A 40-second timeout, denied permissions, invalid GPS or storage errors produce explicit errors and no saved observation. Pending unsaved requests are not durable across app termination: only successfully saved observations appear in the list. Live logging from the species-page plus action uses the same service and rules. Editing an existing observation retains its session link and must remain within the session interval.

## Persistence and migration

`BirdSession` and optional `Observation.sessionID` connect records without duplicating them in a separate log. All existing species history, log badges, discovery filters and logbook/lifelist projections automatically include session observations. The existing observation JSON file now supports a version-2 archive with observations and sessions in a single atomic write. Existing version-1 observation arrays are read without modification and upgraded on the next successful write; original fields and IDs remain intact. Unknown versions, malformed sessions, duplicate IDs, orphaned links and invalid session log intervals block writes. In-memory state changes only after disk success. Session metadata and logs are exportable together from Sessies; the existing observation-only JSON export remains available.

## Verification

Available here: `git diff --check`, tree-sitter parsing of all Swift sources/tests, OpenStep project parsing and source membership checks. Ten session tests cover retrospective individual logs/deduplication/reload/export, active-session restoration, live log timestamps and coordinates, repeat sightings, confirmation-store boundary constraints, legacy migration, atomic write failure, completed sorting and invalid dates/locations. These tests are added but cannot run here: neither Swift nor Xcode is installed.

Required on a Mac/iPhone:

1. Build and run the shared Xcode scheme and all tests under Swift 6; check MapKit, CoreLocation delegate isolation and SwiftUI type checking.
2. Add a completed overnight session; change its map point/name, search in all three languages and select multiple birds. Verify each individual history/logbook entry uses session start time/location.
3. Start live, navigate through every bottom destination and species detail, return using khaki play. Log the same bird twice while moving; compare timestamps, coordinates, total and saved records. Confirm plus on species detail follows live logging rules.
4. Exercise GPS permission denial, approximate GPS, stale fixes, offline geocoding, timeout and failed disk writes. No session-coordinate fallback or unsaved row should appear.
5. Cancel the finish confirmation, then confirm it; verify elapsed timer stops and session appears newest first. Restart while active and after finish, and verify restoration and exports.
6. Validate safe areas, large text/long names, VoiceOver and the 44-point action targets on a small iPhone.

Native build, tests, actual GPS, app lifecycle and visual rendering remain unverified until these checks run.


## Session layout and finish-review update
Active navigation is a khaki icon, with no underline; binoculars grow 2% (21.6 → 22.032 points). The overview action pair has a 6-point gap and charcoal glyphs. Active-session strips use a small filled play glyph on the right. Form titles are 14-point DM Sans, visible begin/end/location labels are removed, and the location-name field is larger (22-point text with padding). Selection headings show the reactive observation count. Bird results have their own bounded 280-point scroll area. The live screen has no location heading and puts the timer in a pale rounded strip.

Empty bird searches request the existing nearby ranking for the chosen coordinates, day, 10 km radius and preceding 30 days. They retain provider order instead of alphabetizing. There is still no configured complete external feed or production global catalog; the unavailable state is explicit and an opt-in six-species unranked sample catalog remains available. A nonempty search searches that sample catalog. No mock ranking is presented as actual local likelihood.

Finish-review is a draft until final confirmation. The session location/name, day, start/end times and individual observation times can be edited; observations can be explicitly removed or added. Changing the session day shifts draft observation dates by the same calendar-day offset while retaining times and original GPS points. Existing live logs retain their individual coordinates and place names when only the session location is renamed/moved. New observations added during review use the selected session location and start time. Original observation IDs/metadata are preserved for retained records. Cancelling review leaves the live session and all records unchanged. Removing records explicitly warns at confirmation that they are also removed from the logbook. Invalid intervals are rejected without dropping records. Concurrently added or edited logs invalidate the draft; reopening reloads the latest records. Completion writes the revised session and logs atomically.

Additional tests cover revised live times with preserved coordinates/identity and unrelated records, invalid intervals, concurrent-edit protection, and atomic add/remove/reload. These are syntax-checked but not executed here. Xcode must also verify the nested scrolling, picker semantics (including overnight sessions and time zones), review cancellation, final confirmation, icon colors and reduced headings.


### Deterministic creation routes — 22 November 2026

The Sessions screen now presents a single identifiable creation mode rather
than updating a live/completed boolean alongside a presentation boolean. The
play action always supplies live mode (`Sessie starten`); the separate clock
retains completed-session entry. The add menu also supplies literal live mode.
Displayed observation counts use `1 waarneming`, including live/review states
and accessibility counts. Native repeated-open/close testing remains pending.
