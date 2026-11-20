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
