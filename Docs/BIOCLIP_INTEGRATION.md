# Photo identification — BioCLIP 2

Implemented 20 November 2026. The photo service default is now
`BioCLIPPhotoService`, replacing the unavailable placeholder. Capture or photo
selection opens a square crop editor (pan/zoom plus accessible zoom buttons).
Cancelling the crop performs no recognition. The accepted crop is analyzed
locally; no photo bytes are uploaded. Results open existing species pages; no
observation is created without the user's normal confirmation/log action.

## Pinned assets and rights

- Imageomics BioCLIP 2, MIT; unofficial Thicket Core ML image tower conversion by
  fearnt, revision `4834c808a722c7204a8c90d57aa32e37963c0462`.
  Archive 270,429,845 bytes; SHA-256
  `11f5f34e0b533c0d8cac74772d3a9f77a894bbdb461f2300201289c4127a56b1`.
- FaunaPulse mammals/birds world v4 reference pack by Valen-Peregrine, revision
  `3007eade814a9124e44389c59d0d56f4839654fb`, 26,455,122 bytes; SHA-256
  `f12ad9a5c5cca37f00fe2a19a085df8b6e60882e1b8f113bcb947d7d36d3af43`.
  The repository and pack explicitly identify embeddings as TreeOfLife-200M
  compilation CC0 and added background embeddings as CC0. Upstream GBIF/COL
  metadata and filtering sources receive attribution in BioCLIP-NOTICE.txt.
- Full MIT permission/copyright text and notices are bundled. In-app photo ID
  links to BioCLIP attribution. No training photos are bundled. The app's label
  crosswalk adapts the existing CC BY-SA world catalog; names/IDs remain stable.

Both archives were actually downloaded outside Git and SHA-256 checked. Model
ZIP integrity passed. The Core ML protobuf was inspected without importing or
running Apple's unavailable inference engine: spec version 8, input `pixels`
Float16 [1,3,224,224], output `embedding` Float16 [1,768]. This is consistent with
the app's provisional iOS 17 target, but does not prove device compatibility.

`BioCLIPAssets.json` pins immutable download URLs and checksums. On first use,
~297 MB downloads; validated assets and compiled model are cached in Application
Support, excluded from backup. Further recognition works offline once cached.
The installer shares one preparation task per service actor. Leaving the photo
page suppresses stale results; a shared model installation already in progress
may finish and populate the cache. No raw photo is retained by the installer.
Existing ZIPFoundation is reused; no additional Swift package was introduced.

## Coverage and scoring

The pack has 15,331 reference rows, 768 dimensions, Float16 little endian. All
rows are validated and normalized before cosine comparison. The importer accepts
exact scientific names or unambiguous existing scientific aliases, yielding
9,954 mapped rows for **9,818 distinct catalog species**. All other rows remain
rejection competitors, including unmapped birds, mammals and five background
prompts. This is coverage of reference labels, not measured identification
accuracy. `PhotoIDCoverage.json` lists all unsupported catalog species.

Duplicate reference rows collapse to the strongest score per species. At most
five mapped results are returned. Abstention requires cosine >=0.20 and a >=0.01
margin over the strongest rejection class. These are **experimental, uncalibrated
starting thresholds**, not validated performance targets. Scores are monotonically
mapped to [0,1] for the existing candidate type; no probability percentage is shown.
A bird-only label set cannot guarantee detection of every non-bird image, and
these additional rejection classes do not establish reliable open-set detection.

Images are decoded to bounded, orientation-correct thumbnails. RGB center-crop
resizing and CLIP channel mean/std produce the planar Float16 input. CoreGraphics
resampling can differ from the reference Python/PIL implementation; compare
embeddings and ranking against reference inference before shipping. An image
containing multiple birds is treated as one crop, not independently detected birds.

## Verification and remaining work

Available checks passed: hashes, ZIP CRC, model protobuf shape/type, all reference
vectors finite and nonzero/near-unit, stable-ID crosswalk, JSON checksum,
registered source/resource paths, Swift syntax parsing and `git diff --check`.
`Scripts/build_photo_labels.py` reproduces labels from the pinned reference pack.

Seven XCTest methods cover rejection, deduplication/top-five, invalid vectors,
bundled coverage, RGB normalization and invalid photos. **Not run here**: no
Swift compiler, Xcode or Apple Core ML runtime. No measured accuracy, inference
latency, memory, energy consumption or native end-to-end success is claimed.

On Mac/iPhone: build and run tests, check crop presentation and VoiceOver,
orientation including EXIF and color-channel/quadrant fixtures; compare the
preprocessing and embeddings with BioCLIP Python; test model download interruption,
retry/checksum failures, restart and airplane mode; measure memory and latency.
Benchmark a separate licensed, representative set including similar species,
juveniles, low light, distant birds, multiple birds and non-bird images. Calibrate
abstention, review missing taxa and report region/taxon-specific results before
claiming broad recognition quality.
