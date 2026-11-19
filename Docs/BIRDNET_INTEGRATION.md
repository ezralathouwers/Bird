# BirdNET+ live integration — 19 November 2026

## What is connected

Geluid-ID now uses `BirdNETCoreMLService` by default. After microphone permission, it prepares the model before opening the audio engine. The first use downloads the official FP16 Core ML archive (~157 MB); following uses load the locally compiled model without network access. Loading/download failure is explicit and does not display sample detections. Photo-ID still has no recognition model.

Audio tap processing writes the local recording and forms three-second native-rate mono windows with a 1.5-second hop. The actor-owned Core ML service uses AVAudioConverter to produce 96,000 Float32 samples at 32 kHz, pads short input, skips digital silence and runs the actual model. Its own spectrogram preprocessing stays inside the model; the compact display sonogram is separate. Only one prediction is in flight. New windows are dropped while busy rather than queueing delayed detections.

The initial score threshold is 0.5. Only Aves output classes are displayed, supporting multiple simultaneous species. Scores are suggestions, not calibrated probabilities. Accepted windows update prior candidate rows and current activity timestamps. Existing star pinning and four-second beige activity highlights receive these real results. Leaving, stopping or restarting invalidates pending results and clears current activity. Stop retains the detections already produced by live analysis; it does not rerun the full recording. The service also exposes completed-file analysis for future use.

## Verified artifact and resources

Immutable source: https://zenodo.org/records/24362980 (BirdNET+ 3.0.1). The downloaded archive and original CSV were independently checked against the publisher MD5 checksums. SHA-256 checksums were then calculated from the full files. Runtime downloads are verified against the exact pinned byte count and SHA-256 before extraction. The model archive is not committed to Git and no model is silently bundled as a >100 MB Git object.

`BirdNETAssets.json` pins the URL, version, bytes and checksums. `BirdNETLabels.json` is a compact projection of the official label CSV: 9,788 bird rows out of 11,725 output classes, including original output indices, BirdNET IDs, scientific names and Dutch/English names. Dutch display names use sentence case. The original CSV SHA-256 is `88d976477fac81127ac8ac4c215c37749d0a6537944112ea606d321317cb7640`.

The native model protobuf was inspected with coremltools protobuf definitions on Linux (no inference): ML Program, specification version 7; input `input`, shape `[1, 96000]`, Float32; outputs `predictions`, `[1, 11725]`, Float16 and `embeddings`, `[1, 1280]`, Float16. The adapter validates the loaded feature schema rather than assuming a generated Xcode model wrapper.

Installation uses a temporary workspace, hash verification, package extraction, Core ML compilation and a versioned cache with a source-hash marker. Downloaded model storage is excluded from device backup. Cancelled/failed installations are cleaned up. Existing recording files and user observation/session/goal data are untouched. Available storage must accommodate the compressed archive, extraction and compilation, not merely the 157 MB download.

## IDs, scope and licensing

All six existing sample species were matched uniquely by scientific name against the official labels; they keep their app IDs. Remaining model labels use a `birdnet-v3:BN…` external namespace and an explicit label-taxonomy version. Existing observation IDs and the global guide's primary taxonomic authority are not migrated. This is recognition-label coverage, not a replacement for the still-pending worldwide illustrated catalog or nearby-report feed. Supplementary label lookup also resolves these external IDs in saved logbook, country, session and goal rows, so their known names do not degrade to “unknown species” after logging. Missing artwork/facts remain placeholders.

Model weights and labels are Apache 2.0. The official model license, use guidance and transformation notice are bundled in Resources/Licenses. ZIPFoundation 0.9.20 (MIT, revision `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`) is the sole new runtime dependency and is pinned through SwiftPM. It extracts the verified official model package; its license is bundled too. Core ML/AVFoundation/CryptoKit are native frameworks. No audio upload, remote inference service, paid service, geomodel or new primary taxonomy was introduced.

## Validation performed here

- Downloaded complete model archive; verified publisher MD5 and independently computed SHA-256.
- Extracted package and parsed actual protobuf input/output schema; verified weight-file presence.
- Parsed all 11,725 CSV rows; validated the 9,788 bird-label projection, unique IDs/indices, in-bounds class mapping and existing six species mappings.
- Swift tree-sitter syntax, OpenStep Xcode project/source/resource membership, SwiftPM version/revision and `git diff --check`.
- Five tests added for three-second overlap, bounded buffering/sample-rate resets, silence/finite fixed-length input, 48→32 kHz conversion, and internal/external ID mapping.

**Not run:** native Swift compilation, Core ML compilation/inference, SwiftPM resolution by Xcode, XCTest, audio-device lifecycle, accuracy and performance benchmarks. Linux protobuf inspection is structural verification, not proof that the iPhone can execute the model.

## First Mac/iPhone verification

1. Open the shared scheme in Xcode, resolve pinned ZIPFoundation and run build/tests. Verify Swift 6 actor/sendability and Core ML/ZIPFoundation APIs.
2. Open Geluid-ID with first-time permission and networking; verify download, hash, extraction, compilation, cancellation, insufficient-storage/network errors and successful cached offline reopen.
3. Compare known audio windows against the official FP16 reference. Include silence, noise, overlapping birds and rare species. Tune score threshold and smoothing with field recordings.
4. Record while changing route, foreground/background, page, add overlay and active-session screen. Confirm no late restart/result or accumulation of obsolete windows.
5. Verify stars, highlights, stable IDs, unknown-species placeholders and explicit user logging, including existing sessions/countries/goals.
6. Measure first-inference delay, steady-state latency, peak memory, thermal/battery cost and whether inference finishes within the 1.5-second hop. Consider a smaller model only if necessary; do not claim real-time performance until measured.
