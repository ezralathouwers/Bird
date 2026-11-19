# Photo and sound identification — 19 November 2026

## Implemented capture and UI

The viewfinder destination opens two actions: Foto-ID and Geluid-ID. Both keep the app's ivory/charcoal style and standard bottom navigation. No Merlin assets, code, database or recognition service were copied.

Geluid-ID requests foreground microphone permission when entered, then automatically starts AVAudioEngine recording. The interface has listening state, elapsed time, a compact **120-point** real sonogram, stop/restart control, recording export and a compact ranked-candidate list. The sonogram is computed from actual PCM samples with 32 log-spaced Goertzel frequency bins from 250 Hz to at most 10 kHz, retaining the latest 100 columns. It is not a simulated waveform. Recording goes to an original UUID `.caf` file under Application Support/BirdingCompanion/Recordings; files are retained across stops and restarts and can be shared after recording stops. Audio-file access is protected by a locked capture sink; PCM buffers remain within the audio callback. No continuous background recording or automatic upload is enabled.

Audio stops on back/navigation, leaving the ID destination, opening root overlays, app background/inactivation during capture or audio interruption. Pending permission/start and recognition results are invalidated by generation IDs. Permission dialogs may complete before automatic startup; backgrounding during permission cancels startup. Subsequent recording starts use a new file, without deleting older recordings. Permission denial, engine failure and disk write errors are visible. Microphone behaviour, interruptions, output formats and realtime performance require physical-device testing.

Foto-ID supports system PhotosPicker image selection and a camera capture sheet. The camera requests authorization only when tapped and reports unavailable/denied access. The photo picker does not request blanket photo-library access. Images are decoded for display, checked against a 20 MB limit and passed as local bytes to the selected service. Loading, invalid-photo, unavailable-model and empty-result states are explicit. No photo is uploaded by the default service. Cancelling camera/picker does not log an observation.

## Recognition integration still required

`PhotoIdentificationService` and `SoundIdentificationService` are injectable boundaries. Their current production defaults explicitly report **not configured**, returning no invented species. There is no bundled Core ML/BirdNET model, licensed remote recognizer or species-label/taxonomy mapping yet. The sound-service boundary currently accepts a completed local recording; a real-time sliding-window species classifier and aggregation are still needed for Merlin-like live species results. Capture/sonogram UI is implemented, but **automatic bird-species recognition is not yet working**.

Selecting a candidate opens the standard species page. Suggestions are never silently saved or added to the logbook, sessions, countries or goals. Candidate scores are validated, deduplicated by stable species ID and ranked. No score is presented as a calibrated probability.

Before integration: verify an appropriate model/code/media license, Apple-device feasibility, supported species, label-to-stable-ID mappings and offline behaviour. Ask before selecting a paid service or uncertain-license dependency, as required by AGENTS.md. The app cannot embed Merlin's proprietary recognition model by assumption. No new external model or paid service was selected here.

## Available verification

`git diff --check`, tree-sitter parsing of 29 Swift app/test files, OpenStep project/source registration checks and microphone/camera Info.plist key validation passed. Five tests were added for score validation/deduplication/order, silence/invalid DSP input, a synthetic-tone sonogram peak, unconfigured photo recognition and injected fixture results/clearing. Fixture suggestions exist only in tests. XCTest execution and native build are unavailable on this Linux machine.

## Required Xcode/iPhone checks

1. Build under Swift 6, checking AVFoundation callback isolation, AVAudioApplication permission API, camera delegate conformance and SwiftUI navigation.
2. Open Geluid-ID with first-time/allowed/denied permissions; verify automatic startup after grant, timer, compact sonogram and real audio file content.
3. Back out, switch bottom destinations, open the add overlay/live session, background the app and trigger interruptions while recording or awaiting permission. Verify recording stops and cannot start late after leaving.
4. Stop/restart, export files, test Bluetooth/multiple routes, audio format/sample-rate changes, no microphone input, disk failure and sustained performance. Verify partial/previous files are retained and no audio callback race occurs on shutdown.
5. Choose a library photo, cancel, take/cancel a camera photo, deny camera access, use a simulator without camera and select invalid/oversized media. Verify stale photo tasks do not replace newer selections.
6. Inject a licensed test provider to test populated/empty/error/stale recognition results. Confirm candidates require an explicit user observation action before they affect any personal records.
7. Test long names, large text, VoiceOver and the compact result list on small phones.

The camera, microphone, sonogram performance, recorded files and all native flows remain unverified until these tests run. Actual live and photo species recognition remains pending model integration.

Research update (19 November 2026): an official BirdNET+ 3.0.1 FP16 Core ML model and Apache-2.0 model/label license have now been found. See `SOUND_MODEL_RESEARCH.md` for verified source/version/checksum metadata, alternatives and the proposed streaming integration. This discovery does not enable recognition yet; no model/runtime has been installed.


## Pinning sound results
A double tap on a sound result toggles a small khaki star beside its Dutch name. Multiple pins stay above ordinary results in the order they were pinned; ordinary results retain score ranking. A single tap still opens the species page, using exclusive double/single tap recognition so the first tap cannot navigate before the pin gesture completes. Context-menu and VoiceOver actions provide equivalent pin/unpin controls. Photo results retain their existing behaviour.

Pins are stored as local UserDefaults preferences by stable ID, with a small species-name snapshot so they can still be displayed without the original candidate. They survive page/app restarts and remain visible even when not currently detected. A star is a viewing preference, not evidence of a current detection; pinning never creates an observation or changes logbook/goals. Corrupt preferences are preserved and not silently overwritten. Live audio highlighting still requires the model/streaming integration and must be derived separately from pins.

Three added tests cover persistent multiple pins/removal, stable pin ordering with missing detections, and deduplicated score order for ordinary results. Syntax checks and `git diff --check` pass; XCTest and single/double-tap interaction must still be checked in Xcode, including VoiceOver and rapid list updates.
