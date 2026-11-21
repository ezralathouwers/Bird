# Illustration batches

## Garden and park birds 01 — 20 November 2026

The user authorized the first complete illustration batch and delegated ordering.
The first batch groups four familiar species commonly encountered in gardens
and parks, making style comparison practical. This does not change their primary
habitat assignments; a tit may still use a woodland footer.

| Species | Classic | Dynamic detail | Front | Rear | Flight |
| --- | --- | --- | --- | --- | --- |
| Merel — Turdus merula | Existing, right-facing | Pulling an earthworm | New | New | New |
| Roodborst — Erithacus rubecula | Existing, right-facing | Singing on a mossy twig | New | New | New |
| Koolmees — Parus major | Existing, reflected right by shared renderer | Climbing twig near caterpillar | New | New | New |
| Pimpelmees — Cyanistes caeruleus | Existing, reflected right by shared renderer | Hanging from seed-bearing twig | New | New | New |

Sixteen new original transparent PNG illustrations complete twenty distinct media
roles across these four species. The classic thumbnails remain separate from the
four-slide detail carousel. Dynamic and flight illustrations face right; front
and rear views deliberately face the viewer/away. No photographs are used.

All source files were copied unmodified into correctly named imagesets. Existing
`SpeciesMediaRole.assetName(for:)` resolves these assets without a UI change:
dynamic, front, rear, flight. The existing app asset catalog is already a bundle
resource; no new project source entries are needed. `ArtworkManifest.json`
records source filenames, hashes, dimensions, rights, representative plumage,
reference classic asset and review state. Original source images remain intact.

Visual checks covered role, complete bird framing, two wings/legs where visible,
right-facing side/flight views and key species marks. Facts were compared to RSPB
species accounts linked in the manifest, without copying their images or prose.
Blackbird/great tit use representative adult male plumage; robin/blue tit use
adult plumage without sex distinction. These images do not cover every age,
sex, season or subspecies. Generated feather/toe details and seed/plant forms
still need independent expert review; soft alpha edges should be checked against
the app ivory background. No expert anatomical certification is claimed.

Verification: all sixteen PNGs decoded and have transparency, source/asset hashes
match, every imageset has a valid catalog ID/role and a unique source, all four
species have five separate assets. Content inventory now reports four fully
illustrated species globally. `python Scripts/species_content_inventory.py` and
`git diff --check` pass. The CSV uses LF for clean repository diffs. No runtime
logic was changed and no new unit tests are needed for the asset-only addition.
Native rendering, slide sizing, alpha edges and bundled asset loading remain
unverified until Xcode runs on Mac/iPhone.

## Garden and park birds 02 — 20 November 2026

Fifteen new images complete all five roles for:

| Species ID | Species | Dynamic scene | Representative plumage |
| --- | --- | --- | --- |
| birdnet-v3:BN07155 | Huismus / Passer domesticus | Dust bathing | Adult male, breeding |
| birdnet-v3:BN03948 | Vink / Fringilla coelebs | Stepping onto twig with seed | Adult male, breeding |
| birdnet-v3:BN06452 | Winterkoning / Nannus troglodytes | Singing on mossy root | Adult, sex not distinguished |

Classics, dynamic scenes and flight views face right; front/rear views face
forward/away. All fifteen are separate transparent original PNGs. Visual checks
covered framing, role and diagnostic features: sparrow grey cap/black bib and
lack of a tree-sparrow cheek spot; chaffinch cap, wingbars and outer tail;
wren's short cocked tail, brown barring and fine bill. RSPB factual references
are recorded in the manifest; their media were not copied. The existing robin
classic was the drawing-style reference, not the species identity reference.
Independent expert anatomical review and user/native review are still pending.

Global asset coverage is now seven complete species, nine classic portraits,
nine dynamic illustrations and seven each of front/rear/flight. All original
source images remain unchanged. `Scripts/install_artwork_batch.py` validates all
batch records and image files before installation and refuses existing assets.
Its mapping input uses `id`, `role`, `path` and optional `referenceURL` and
`representativePlumage`; Pillow is a maintenance dependency, not an app package.

These are the first illustrated species using namespaced world IDs. Asset keys
now replace ':' with '-' independently of persistent IDs, avoiding platform
filename restrictions while preserving every observation/taxonomy ID. Classic
portrait checks and image rendering in lists, observation forms and map markers
now use the same `SpeciesMediaRole.classic.assetName(for:)` function as detail
slides. Sample keys are unchanged. All 11,173 current keys were checked unique.
Two XCTest methods were added for this behavior, but were not run without Xcode.

Verification: PNG decoding/alpha, source hashes, 15 unique asset names, all five
roles per new species, current catalog identity and existing asset-catalog
resource membership checked; inventory regenerated, Swift syntax parsed and
`git diff --check` passed. No native build or simulator/device test was run.

## Woodland/water completion 03 — 20 November 2026

Six new transparent illustrations complete the existing kingfisher
(`sample-alcedo-atthis`) and great spotted woodpecker (`sample-dendrocopos-major`)
sets: front, rear and right-facing flight for each. Existing classic portraits
and dynamic fish-carrying/pecking compositions are retained, including the shared
right-facing correction for the kingfisher classic. Global coverage is now nine
complete species, with nine assets in each of the five roles (45 bird assets).

Visual review checked complete framing, correct requested view and main field
marks: kingfisher's dark male bill, short tail, white throat, orange underside and
blue dorsal stripe; adult male woodpecker's small red nape patch, black crown,
large white scapular patches, spotted flight feathers and red undertail coverts.
The source references are in the manifest. Images remain generated illustrations,
not independently certified anatomical references; toe details and flight-feather
patterns still need expert/user review. A broad halo in the initial kingfisher
rear image was cleaned with image generation before installation; the original
and cleaned source filenames are retained in provenance.

No Swift or observation-data changes were needed. All six generated PNGs were
copied unchanged into role-specific imagesets after review. Image decoding,
transparency, unique role names, source SHA-256 equality, both completed sets and
asset-catalog bundle membership checked; content inventory and `git diff --check`
passed. Native image loading, ivory blending and carousel layout remain to be
verified in Xcode. No native build or tests were run on Linux.

## Flight pose replacement 04 — 20 November 2026

The earlier flight-facing directions in batches 01–03 are superseded. All nine
flight images now show a centered underside, head up, tail down and both wings
extended left/right. The fourth slide and asset names remain unchanged. No other
roles were replaced. See FLIGHT_ILLUSTRATION_STANDARD.md for the permanent future
generation/import rule and retained prior-version provenance.

## Woodland 05 — 21 November 2026

Boomklever (Sitta europaea, birdnet-v3:BN09339) and boomkruiper
(Certhia brachydactyla, birdnet-v3:BN01798) each receive all five roles.
Classic portraits face right; dynamic compositions show headfirst descent and
upward bark climbing respectively. Both flight illustrations use the centered
ventral projection. Front/rear views remain separate originals. Main markings,
framing and poses were visually reviewed against Vogelbescherming species
descriptions; independent anatomical and native rendering review remain pending.

Ten original transparent PNGs are copied unchanged, with source SHA-256 values
and references recorded in ArtworkManifest.json. The importer accepts square
originals of at least 1024 pixels per side as well as wide flight originals;
it never upscales them. Coverage is now 11 complete species and 55 role assets.

Scripts/illustration_production_queue.py inventories all 11,173 catalog records
by habitat in Docs/IllustrationProductionQueue.csv and .json. It records missing
roles and prioritizes habitat batches; it does not run generation in the
background. Remaining work: 11,162 species and 55,810 illustrations. Refresh the
queue and species content inventory after each batch.

Verification: import preflight, PNG decoding/transparency, unmodified source
hashes, unique catalog/asset IDs, five roles per new species, full queue coverage
and git diff --check. Xcode is unavailable: native image loading, carousel
layout, transparency against ivory and device performance remain unverified.
