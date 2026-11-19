# Countries and goals — 19 November 2026

## Countries

The globe opens countries with logged observations, sorted by Dutch country name. Each row has a flag (including Belgium) and a unique species count; repeated observations of the same stable species ID count once per country. ISO country codes are normalized, so lowercase/whitespace variants group together. Missing or invalid countries are excluded from country totals and explicitly counted below the list. No country is inferred from an arbitrary place-name string.

A country opens the existing logbook layout filtered to that country: classic right-facing thumbnails, Dutch Fraunces names and smaller English DM Sans, family grouping by default, optional Latest discovered order based on the earliest observation **in that country**. Unknown catalog IDs remain visible. Selecting a species opens its standard detail page; that species page still shows global species history. The logbook's explicitly labeled all-observations export remains global.

## Goals

The checklist destination lists locally saved named goals with progress. Creation requires a nonblank name and at least one selected species, with search by Dutch, English or scientific name. Current selection uses the six-species sample catalog. A production global catalog is still pending.

Each goal stores stable species IDs, not a mutable checked flag. Checkmarks and progress derive from all personal observations, including records before goal creation and session logs, using the same logged-species meaning as the logbook. Repeat sightings count once. Removing the only observation of a species automatically unchecks it. Different goals may include the same species. Unknown IDs remain in stored goals and display an explicit fallback rather than silently disappearing. Goal detail links open the standard species page.

Goal records persist in a version-3 atomic archive alongside observations and sessions. Existing observation arrays and version-2 session archives without goals remain readable; they migrate on the next successful write. Every ordinary observation save and session operation retains goals. Failed writes publish no unsaved goal. Invalid goals or duplicate IDs block archive writes rather than dropping data. The full JSON archive export includes goals; it is available from Goals and Sessions. The existing observation-only export remains available.

## Navigation

Left to right: binoculars (Discover), viewfinder (Identify), clock (Sessions), raised plus/live-play, checklist (Goals), globe (Countries), bird (Logbook). The central action retains existing observation-map close and active-session behaviour. Icons stay label-free, with Dutch VoiceOver labels, at least 44-point targets and khaki selection without underlines. Sessions moves to the left half. The central circular button remains 72 points; small-screen spacing requires simulator verification.

## Verification

Available checks: `git diff --check`, tree-sitter parsing of 25 Swift app/test files, OpenStep Xcode-project parsing and all source-file membership checks. Seven added tests cover country normalization, deduplicated counts, country-specific discovery ordering, automatic goal progress, archive reload/export, retaining goals through session writes, version-2 migration, invalid goals/failed writes and corrupt archive preservation. Tests are written but cannot execute in this Linux environment without Swift/Xcode.

Mac/iPhone checks:

1. Run the full test suite and native build, including SwiftUI navigation and Swift 6 isolation/type checking.
2. Log the same species twice in Belgium and once in another country; verify counts, flags, scoped family/discovery lists and species links.
3. Open old records without country and confirm they remain visible globally and are reported as unassigned on Countries.
4. Create a goal containing an already logged species and an unseen species. Log the unseen species individually and in a session; check that all goal screens update without a manual toggle.
5. Finish-review/remove a session's only log of a target species; verify its goal checkmark clears. Restart and export to verify goals, sessions and observation IDs survive.
6. Check seven navigation slots, the raised central circle, active session play, small devices, large text, long country/goal names and VoiceOver.

No native build, simulator rendering or XCTest execution has been performed here.
