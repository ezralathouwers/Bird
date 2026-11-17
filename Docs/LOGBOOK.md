# Species logbook — 17 November 2026

The bird navigation destination is now a lazy scrollable list of unique **logged species**, not repeated observation rows. Every row uses the shared primary artwork, Dutch name and smaller sentence-case English name. A row opens that species' detail page; its Waarnemingen tab retains the individual records. The global JSON export remains at the bottom. The plus button on a species page opened from Logboek uses that species, and the bird navigation icon returns to the logbook root.

Default sorting is **Per familie**. Families are sorted alphabetically by Dutch name, with species alphabetically inside each group. This does not imply a newly selected global taxonomic order. **Laatst gelogd** removes all family groups and sorts by the most recent saved observation's `createdAt` for each species; date ties use Dutch name then stable ID. Editing a location/date does not rewrite createdAt, so it does not silently reorder the species. The sort picker stays above the list; a new logbook session defaults to families.

Both modes derive from the same personal records and stable IDs. Multiple observations never duplicate a species. Legacy uncertain/captive entries remain logged species (as with logged badges), separate from stricter lifelist rules. Unknown species IDs are retained as explicit unknown rows and grouped under Familie onbekend, never silently dropped or mapped to kingfisher. Empty and failed-store states are separate. No observation schema or persisted records were changed.

## Family metadata

Added optional read-only family metadata to the current mock catalog. The six assignments were checked against Vogelbescherming's species pages on 17 November 2026:

- Merel → Lijsters / Turdidae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/merel
- Koolmees → Mezen / Paridae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/koolmees
- Pimpelmees → Mezen / Paridae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/pimpelmees
- Roodborst → Vliegenvangers / Muscicapidae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/roodborst
- Grote bonte specht → Spechten / Picidae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/grote-bonte-specht
- IJsvogel → IJsvogels / Alcedinidae: https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/ijsvogel

This enriches sample metadata without changing existing species IDs or selecting a production taxonomic authority. A production catalog and versioned mapping are still needed for global coverage.

## Mac checks

1. Empty store: open Logboek; confirm empty message, no invented demo observations.
2. Save two records of the same species and one of another species. Confirm two species rows only, correct Dutch/English names and images.
3. Log both tit species. Default mode must group both under MEZEN.
4. Switch to Laatst gelogd. Confirm no family headings and newest save first, including backdated observations saved now.
5. Edit an existing observation; confirm no duplicate species or changed creation-order. Return from detail and verify sort selection persists.
6. Open an unknown-catalog fixture: ensure the record remains accessible and export still preserves it.
7. Check long names, Dynamic Type, VoiceOver, all row/filter targets and the fixed bottom navigation.
8. Run the five new projection tests in Xcode. Native rendering and test execution remain unverified here.
