# Species-page looped audio — 22 November 2026

The existing speaker button now controls a per-species recording directly:
first tap starts continuous playback; second tap stops it. No playback sheet
opens. The active symbol is a stop icon. If availability is unknown, lookup fails
or no suitable recording is found, the button is omitted. Metadata lookup never
autoplays. Leaving the page stops playback and invalidates pending lookup results.

Playback also stops for app background/inactivity, audio-session interruptions,
photo/observation/full-screen-map presentation, and root add/live-session/map
overlays that previously only hid the underlying navigation stack with opacity.
It does not automatically resume. It creates no observations and requests no
microphone permission. Playback uses AVQueuePlayer with a retained AVPlayerLooper;
stop releases the queue/loop observer and deactivates this playback session.
Playback failure ends the loop and displays a short error. Neither audio inference
nor model output is used as a recording source.

## Source and coverage

The provider uses Wikimedia Commons' public MediaWiki metadata API, keyed by the
existing scientific species name. It retrieves metadata only for visited pages,
not a global catalogue crawl. Exact scientific-name matches in the file title are
required; pronunciation/spoken-word titles are excluded. English/Dutch-name-only
matches and ambiguous historical-name guesses are not used. This improves matching
but is not an independent expert validation of the underlying recording.

A usable creator, source page and supported CC BY / CC BY-SA / CC0 / public-domain
license with its official URL are required. Only HTTPS URLs on Commons and its
upload host are used. Original MP3/M4A/AAC/WAV/AIFF or an official MP3 transcode
are selected; Ogg is not assumed supported by iOS 17. No eBird or Xeno-canto key,
website scraping, paid service or new package dependency is required. Some
Commons files originated on Xeno-canto; Commons-provided file provenance and
license are retained. The catalogue's persistent species IDs are unchanged.

Metadata results are cached in memory for one day (success) or ten minutes
(no match). Network errors are not cached. Playback streams from Commons and
needs network access; no offline-download coverage is claimed. The Info/source
screen lists loaded recording credits with creator, original page and license.
No forced credits dialog appears when pressing the speaker button.

## Verification

- Live API checks found licensed native-format recordings for ekster, ijsvogel,
  grote bonte specht, houtduif and great hornbill. One MP3 byte-range check
  returned HTTP 206 with audio/mpeg; no media file was added to public Git.
- Swift syntax and new Xcode source membership checked in cloud.
- XCTest fixtures added for exact-name/license/host filtering, rejecting spoken
  files, official MP3 derivatives for Ogg, missing/offline lookup, start/stop/
  leave-page behavior via a fake player, late lookup after leaving and playback
  failure. Fixtures do not fetch media, activate an audio session or use a key.
- Xcode build, XCTest execution, actual device/simulator audio, repeated loop
  transitions, buffering/failure, rapid tapping, navigation/sheet/root overlays,
  background, phone interruption and accessibility must be checked on Mac/iPhone.
  No successful native audio playback/loop test is claimed by this cloud work.

## Commons metadata decoding fix — 22 November 2026

A real Commons response includes `CommonsMetadataExtension.value: 1.2` among
otherwise textual `extmetadata` values. Decoding every dictionary entry as a
String rejected the entire response, leaving the audio control hidden even
for a species with a supported recording. Attribute decoding now accepts only
strings for the values we actually use and treats unrelated non-string values
as empty. Numeric/missing attribution still cannot qualify a recording.

A regression fixture includes both numeric and boolean bookkeeping plus valid
artist/license values; a second assertion rejects a numeric artist. The live
Commons request for Turdus merula confirmed this mixed metadata schema. Native
XCTest, button appearance and AVPlayer looping still require Xcode verification.
