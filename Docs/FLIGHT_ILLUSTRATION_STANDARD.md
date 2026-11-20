# Flight illustration standard

Approved 20 November 2026. Applies to every species' fourth detail slide,
including all existing assets and every future batch. This supersedes earlier
right-facing side/three-quarter flight directions in illustration batch records.

## Required pose

- A centered **ventral view**, camera directly below a bird flying overhead.
- Head and bill toward top center (12 o'clock); tail toward bottom center.
- Wings extend left/right at approximately equal height, both fully visible.
- Natural elbows, primary feather fanning and small asymmetries are appropriate.
- Visible breast, belly and **underwings** must match the species. Do not simply
  copy dorsal wingbars, colorful backs or crown patches onto ventral surfaces.
- Whole bird, beak, tail and feather tips inside the canvas; no cropped parts.
- Same original natural-history watercolor/pencil style, transparent background,
  no perch, labels, sky, halo or drop shadow. It is an illustration, not a photo.

The user's attached overhead gull photograph supplies the composition only.
Do not copy gull proportions/markings onto songbirds or other species. Classic
thumbnails still face right; dynamic/front/rear roles and slide ordering do not
change. The flight accessibility label is now 'Onderaanzicht in vlucht'.

## Reusable generation direction

```
Centered orthographic ventral view of [species], camera directly below an
actively flying bird overhead. Body vertically aligned, bill/head pointing to
top center and tail to bottom center. Both wings fully spread left/right at
roughly equal height with natural joints and feather fanning. Show species-
correct breast, belly and underwing plumage, not back/dorsal wing surfaces.
Feet tucked, entire bird inside canvas with breathing room. Natural-history
watercolor and fine pencil illustration, true transparent background, no shadow,
halo, labels, perch or scenery. Not a banked side view or dorsal specimen.
```

Add independently checked species-specific ventral diagnostic features,
proportions and representative sex/age. Visually inspect every output.

## Import and versioning

New flight rows in `Scripts/install_artwork_batch.py` require
`"projection": "centered-ventral-spread"`. The installer records source/display
facing `up` and this projection in `ArtworkManifest.json`; it rejects missing or
other projection declarations. This metadata check does not determine the real
pose from pixels; visual review is still required. Wide flight images can use a
1536 x 768 or larger canvas; other roles retain the existing resolution check.

All nine current flight assets were redrawn and replaced at their existing asset
names, preserving source and stable species IDs. Current records have version 2,
new hashes/dimensions and `previousVersions` with the prior full provenance.
Previous pixels remain in Git history and original generated source files.
Current files are unmodified copies of the new generated PNGs.

Validation passed: nine unique current flight records, all with the approved
projection and up orientation; PNG decoding/transparency; new and old original
hashes; all nine complete five-role sets retained; Swift model syntax and
`git diff --check`. Installer rejection of missing projection and refusal to
overwrite an existing asset were exercised without writes. No native build,
XCTest, simulator or iPhone rendering ran here. Independent anatomical review,
transparent-edge appearance and full-width carousel framing remain Xcode/user
checks; no automated pixel-based or expert anatomy certification is claimed.
