# Shared habitat footer illustrations — 19 November 2026

## Intent and selection rules

Use **24 reusable landscape scenes** instead of one footer per bird. These are illustration/composition categories, not a claim to replace IUCN habitat codes or describe the complete ecology of a species. The main bird artwork remains species-specific; the decorative footer is shared.

Each reviewed species assignment has one primary scene, zero or more secondary scenes, source URLs, review date and status. The primary is a representative visual choice, not the species' only habitat. Seasonal, geographic and generalist variation can be recorded later without creating thousands of images. A missing or draft assignment does not receive a guessed generic scene. No automatic mapping is made from taxonomic family, geographic range, photo background or Sound ID output.

## Scene library

| ID | Leefomgeving | Illustration brief |
| --- | --- | --- |
| `rivers-streams` | Beken en rivieren | Heldere, rustig stromende beek met overhangende tak, begroeide oevers en een klein stukje steile zandwand. |
| `lakes-ponds` | Meren en plassen | Open zoetwaterplas met lage oeverplanten en zachte rimpelingen; een rustige verre oever. |
| `reedbeds-marsh` | Riet en moeras | Rietkragen, lisdodden, nat gras en kleine open watervlakken; enkele lage wilgen aan de rand. |
| `swamp-forest` | Moerasbos | Wilgen- en elzenstammen boven ondiep water, natte bodem en verspreide zegges. |
| `mangrove` | Mangrove | Mangrovewortels in warm ondiep getijdenwater, een lage slikkige oever en compacte tropische bladeren. |
| `sandy-coast` | Strand en duinen | Licht zand, lage duinen en helmgras met een smalle branding aan de horizon. |
| `tidal-flat` | Wadden en slikken | Slikplaten met geultjes, ondiep getijdenwater en een lage rand kweldervegetatie. |
| `rocky-coast` | Rotskust en zeekliffen | Gelaagde kustrotsen, lage klifranden, enkele zilte grassen en een smalle strook zee. |
| `open-ocean` | Open zee | Weidse zee met subtiele golven en laag schuim; geen land of bomen. |
| `temperate-woodland` | Loofbos en gemengd bos | Een paar herkenbare loofboomstammen, gemengde bladerkronen, mos en rustige ondergroei; lichte open plek. |
| `conifer-forest` | Naaldbos en taiga | Sparren- en dennenstammen, een gelaagde donkere naaldkroon, mos en een sobere bosbodem. |
| `tropical-rainforest` | Tropisch regenwoud | Hoge tropische boomstammen, brede bladeren, lianen en gelaagde vochtige bosvegetatie. |
| `dry-open-woodland` | Droog open bos | Ruim uiteenstaande bomen, droge bladeren en licht gras; veel open grond tussen de boomgroepen. |
| `savanna` | Savanne | Goudgroene grasvlakken en enkele schermvormige bomen, met een lage open horizon. |
| `grassland-steppe` | Grasland en steppe | Uitgestrekt natuurlijk grasland met lage kruiden, enkele kale grondplekjes en nauwelijks bomen. |
| `heathland` | Heide en laag struweel | Lage heidepollen, schrale grassen, zandige stukjes bodem en wat laag struikgewas. |
| `mediterranean-scrub` | Mediterraan struweel | Droog, compact groenblijvend struikgewas, lichte rotsen en kruiden; sober warm palet. |
| `desert` | Woestijn en halfwoestijn | Zandige en stenige bodem met enkele droge struiken; veel rustige open ruimte. |
| `alpine-rock` | Gebergte en rotsland | Alpiene rotsen, lage berggrassen en een verre bergkam; geen generieke hoge bosvegetatie. |
| `tundra` | Toendra | Boomloze lage mossen, korstmossen en dwergstruiken met enkele natte laagtes. |
| `polar-coast` | IJs en poolkust | Bleke ijsranden en een sobere donkere rotskust naast koud water; zachte blauwe accenten. |
| `farmland` | Akkers en weilanden | Een gevarieerde weide- en akkerrand met lage kruiden, gras, een haag en een verre solitaire boom. |
| `gardens-parks` | Tuinen en parken | Een grasrand, bloeiende struiken en enkele volwassen bomen; subtiel tuinpad, geen opvallend gebouw. |
| `urban` | Stad en bebouwing | Een rustige dakrand en geveldetail met wat stedelijk groen; geen tekst of plaatsgebonden herkenningspunten. |

## Initial source-checked assignments

| Species | Primary footer | Additional habitats |
| --- | --- | --- |
| IJsvogel | Beken en rivieren | Meren/plassen; riet/moeras |
| Grote bonte specht | Loofbos/gemengd bos | Tuinen/parken; naaldbos |
| Koolmees | Loofbos/gemengd bos | Tuinen/parken |
| Pimpelmees | Loofbos/gemengd bos | Tuinen/parken; riet/moeras |
| Roodborst | Loofbos/gemengd bos | Tuinen/parken |
| Merel | Tuinen/parken | Loofbos/gemengd bos |
| Torenvalk | Akkers/weilanden | Heide; stad |
| Blauwborst | Riet/moeras | Moerasbos |
| Hop | Droog open bos | Grasland/steppe; tuinen/parken |
| Dubbelhoornige neushoornvogel | Tropisch regenwoud | — |

Sources: the nine relevant Vogelbescherming bird-guide habitat sections and Animal Diversity Web's Great Hornbill habitat account were consulted on 19 November 2026. URLs are stored per assignment in `SpeciesHabitatAssignments.json`. Only the factual visual classifications and source links are recorded; no descriptions or copyrighted illustrations were copied. The choices are representative themes, including locally described habitat use, not a globally exhaustive habitat dataset.

## Reuse and rendering

`HabitatSceneCatalog` loads and validates scene/assignment IDs. `HabitatFooter(species:)` selects the source-checked primary scene and renders its asset only if available. There is no wrong-habitat fallback. Unknown species and missing art add no artificial footer space. Multiple species with the same scene ID automatically share one asset.

The river scene currently aliases the existing `KingfisherHabitat` asset, preserving its appearance and provenance without duplicating it. The remaining asset keys are `habitat-<scene-id>`. The existing footer remains 84 points high, full width, bottom aligned immediately above the main navigation, decorative and hidden from VoiceOver. No other species-detail layout is changed.

## Art production brief

- Produce one original landscape strip per scene; no birds, animal silhouettes, map markers, names or UI text. A species in the footer would make reuse misleading.
- Use the approved detailed natural-history watercolor/colored-pencil direction, neutral ivory transition at the top, charcoal-neutral overall harmony and restrained natural greens/blues.
- Design around a roughly 5:1 visible strip. A high-resolution master around 1920×420 is suitable for the existing phone footer; keep important habitat cues in the lower/central area and allow edge cropping.
- Use a low horizon and uncluttered composition so the footer supports the hero rather than competing with it. Avoid recognizable regional landmarks unless a scene is explicitly regional.
- Keep original files, creation/source/license details and review status in the asset manifest. These are landscape scenes, separate from each species' five illustration roles.

Prioritize shared woodland, gardens/parks, farmland, reedbeds/marsh, tropical rainforest and dry open woodland next; the river scene already exists. These cover the current ten-species pilot with seven primary scene IDs. The other scene briefs are ready for the next regions/families.

## Coverage and next data work

Current classification: 24 scenes, 10 source-checked species assignments, **11,163 unassigned records** (including the compatibility record), and one existing scene asset. A habitat category existing does not mean every species has already been classified.

Run `python Scripts/habitat_inventory.py` to validate mappings and rebuild `HabitatCoverage.json` and `HabitatAssignmentInventory.csv`. The full inventory leaves unknown habitat fields blank. Extend it in source-reviewed species batches or through a licensed habitat dataset with explicit mapping/review; do not mass-fill using family guesses.

## Verification

Available checks: Swift syntax parsing, OpenStep Xcode source/resource registration, JSON/reference/species-ID validation and `git diff --check`. Four tests cover shared-scene reuse, missing/draft handling, invalid/duplicate data and the bundled pilot/kingfisher mapping. Native build, XCTest and footer cropping/safe-area rendering still require Xcode. No new illustration was generated in this change.
