# Sound-model research — 19 November 2026

Recommendation for evaluation: **BirdNET+ V3.0.1 Global 12K, official FP16 Core ML export**. This is a research recommendation, not an installed dependency or tested integration.

## Verified sources

- Developer repository: https://github.com/birdnet-team/birdnet-V3.0-dev
- Architecture/species coverage: https://github.com/birdnet-team/birdnet-V3.0-dev/blob/main/docs/model.md
- Current immutable model record: https://zenodo.org/records/24362980 (DOI 10.5281/zenodo.24362980)
- Record metadata checked directly: https://zenodo.org/api/records/24362980
- Model license read directly: https://raw.githubusercontent.com/birdnet-team/birdnet-V3.0-dev/main/MODEL_LICENSE.md
- Use/branding guidance: https://raw.githubusercontent.com/birdnet-team/birdnet-V3.0-dev/main/ACCEPTABLE_USE.md
- Mobile reference app: https://github.com/birdnet-team/birdnet-live-app
- Mobile model license: https://raw.githubusercontent.com/birdnet-team/birdnet-live-app/main/MODEL_LICENSE
- Older alternative: https://birdnet-team.github.io/BirdNET-Analyzer/stable/models.html
- Perch alternative: https://www.kaggle.com/models/google/bird-vocalization-classifier/tensorFlow2/perch_v2/2 and https://github.com/google-research/perch

## Choice and version distinction

The current architecture documentation reports 9,788 bird species among 11,725 audio output classes. Filter non-bird classes when displaying bird suggestions. Classification scores are not calibrated probabilities.

The developer README lists native Core ML support on iOS 16+; its fixed input is three seconds of waveform at 32 kHz. The display sonogram must remain independent of model preprocessing. Version 3.0.1 is dated 19 November 2026 and refreshes exports; do not mix it with older same-named files or preview releases.

The immutable Zenodo API verifies:

| Artifact | Bytes | Publisher MD5 |
| --- | ---: | --- |
| `BirdNET+_V3.0_Global_12K_FP16.mlpackage.zip` | 156525393 | `e2cc0ee961da3f52aee2428c5326f110` |
| `BirdNET+_V3.0_Global_12K_Labels.csv` | 8007144 | `bb25847af8a581e1382081382f01e762` |
| `BirdNET+_V3.0_Global_10K_BNL.zip` | 69567716 | `b2ee809cbb67c0988afcbd2d156d4fc9` |

These are publisher metadata, not hashes independently verified against downloaded binaries. No model binaries were downloaded. Archive size is not runtime RAM or compiled app size. The smaller BNL package is an alternative for mobile inference, using ONNX rather than the native Core ML artifact; it would need an extra runtime or a validated conversion.

## Licensing

The official model license explicitly covers audio/geomodel weights, converted/pruned versions and labels under **Apache 2.0**. Code is separately MIT. Use guidance says it does not add conditions to that license and cautions against implying official endorsement. Preserve copyright, license, applicable notices and transformation details when bundling. No need to infer model rights from a code repository's MIT badge.

BirdNET 2.4 remains a smaller fallback (official documentation: 50.5 MB FP32, 6,522 classes), but its models use **CC BY-NC-SA 4.0**; that is materially different from V3.0.1. Perch v2's published model page lists Apache 2.0 and broad bioacoustic classification, but a native iPhone path/performance has not been verified in this research. Do not infer recognition superiority from species count alone.

## Proposed integration with this app

1. Pin/download the official model, labels and licenses; verify checksums and inspect the actual Core ML input/output schema on macOS. Keep the artifact version/checksum in provenance.
2. Implement a native Core ML adapter behind the identification interfaces. Add a streaming audio-window interface: the current sound-service contract only analyzes completed files, and is insufficient by itself for live results.
3. Convert captured audio to 32 kHz mono Float32. Maintain a bounded ring buffer and analyze 96,000-sample windows with overlap on a worker, never blocking the audio tap. Drop/skip backlog and reject silent/invalid windows before inference.
4. Decode species labels, retain bird classes, and explicitly map external IDs to the app's stable internal IDs. The six-species sample catalog does not yet cover these outputs. Using model labels must not silently change the app's taxonomic authority or existing observation IDs.
5. Smooth candidates across successive windows, tune per-species thresholds with field recordings, and preserve unknown IDs for review. Several birds may be present simultaneously; do not apply a mutually exclusive softmax.
6. Optionally use location/season metadata to reduce implausible suggestions, allowing unusual visitors. A geomodel estimates occurrence and cannot substitute for the last-30-days report-frequency ranking requested for Discover.
7. Keep results as suggestions until the user logs them. Retain existing recording, local export and lifecycle-stop behaviour.

## Still to test

On an actual target iPhone: Core ML loading/operator support, numerical agreement with the official reference, all-zero audio, overlapping calls, 3-second inference latency, sustained CPU/Neural Engine use, thermal/battery effects and peak memory. No model inference, accuracy benchmark, Core ML compilation or iPhone runtime test was performed here. The recommendation is technically promising, not proof of real-time performance.
