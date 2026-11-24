# AGENTS.md — Codex instructions for Birding Companion

You are working on a private, non-commercial, native iPhone birdwatching app. `PROJECT_BRIEF.md` is the product and design source of truth. Read it before making architectural or UI decisions.

## Goals and priorities
1. Deliver a usable, reliable offline-first observation log and global illustrated bird guide.
2. Match the approved kingfisher species-detail visual direction closely, without sacrificing accessibility or responsiveness.
3. Preserve data integrity, privacy, and exportability.
4. Keep integrations (eBird, BirdNET, photo ID, CloudKit) modular, licensed, and testable.
5. Prefer incremental, reviewable changes over broad speculative rewrites.

## Latest species-page design override (22 November 2026)
The user's kingfisher and great hornbill right-hand reference panels supersede
older species-page layout rules below: three tabs (Overzicht, Informatie,
Waarnemingen) in an outlined ivory strip with a beige active segment directly
below higher English/Dutch headings. Overview is only large bottom-aligned
artwork with horizontal bleed; no facts, habitat footer or dots. Four slides
loop both ways. Span/bio, a compact interactive map and habitat footer belong
on Informatie. Keep Fraunces Dutch titles with -2% tracking and tighter leading.
See Docs/SPECIES_DETAIL_REDESIGN.md; native visual matching remains unverified.

Latest user override, 23 November 2026: show only existing detail illustrations
in the species carousel. With zero or one available slide, disable swiping.
If no detail illustration exists but a classic portrait does, temporarily show
the classic portrait in the overview, preserving its right-facing orientation.
This supersedes the older no-classic-fallback/placeholder-slide rule below.

Latest user override, 24 November 2026: keep overview artwork sizing/placement,
but allow tall illustrations to continue behind the title and tab strip rather
than clipping at the content top. The drawing canvas spans the page; the image
fit still uses the below-header viewport. On Waarnemingen, pin the count above
the scrolling rows, fade rows at the top only after scrolling, and add 50pt
bottom padding. Discovery has info, backup and nearby-settings icon buttons.

Latest user feedback, later 24 November 2026: pin the headers on Logbook,
Sessions, Goals, Identify and Countries with scroll-only top fades. Logbook
search is scoped to logged species; sort is an icon menu. Countries rank by
unique species count, not observation count, and expose a first-observation
map. Species observation-list bottom padding is now 104pt (24+50+30). Keep
observation/session/goal deletion explicit and atomic; session conversion keeps
exact logs and removes only their session link. Audio result quick-add is an
explicit user confirmation and may atomically create a live session. See
Docs/LOGBOOK_SESSIONS_MAP_UPDATE.md and Docs/LOGBOOK_ARTWORK_API.md.

## Non-negotiable design rules
- Warm **light neutral ivory** background, not dark/yellow parchment. Final tokens must be validated against the user's approved image.
- Characterful serif **only for the Dutch species title in the upper-left**; all other interface text, including English name, active tabs and navigation, is modern sans-serif.
- Dark charcoal typography; taupe/dark beige icons and accents; no green active tabs.
- The five species-detail tabs are in one rounded darker-beige container, with a light-ivory pill for the active tab. No underline or rule beneath it.
- Species page top nav contains back and centered title; no top-right share/bookmark/overflow controls.
- Beside the heading: three small round icon-only buttons for audio, Google image results, and `+` observation logging.
- Kingfisher illustration: one prominent hero plus three smaller views, without view labels. Do not show habitat illustration or distribution map on the overview screen.
- Facts display icon and value, no visible field labels; provide descriptive VoiceOver labels. Use a consistent small taupe icon family.
- Keep a 44-point minimum touch target and support Dynamic Type, safe areas, small screens, long Dutch names and VoiceOver.
- Do not use the original mockup as a literal source of scientific truth. Validate content separately.

## Owner bulk acceptance override — 24 November 2026

The owner explicitly requested accepting all locally API-generated primary and
dynamic images together, with specific corrections later, instead of mandatory
per-image checkboxes. The local importer may install those exact hash-bound
candidates with `ownerAcceptance.method: bulk-user-accepted-unreviewed`.
Do not mark anatomy/noProps/style checks as performed: keep those flags false
and record that individual visual review is pending. Technical file, provenance,
ID, transparency and no-overwrite checks remain required. Existing individually
reviewed assets retain their real reviews. This exception applies to the owner's
explicit bulk import, not automatic approval of future image generations.

## Latest approved artwork direction
- Dynamic/detail illustration top edges must finish naturally or fade to transparency; never sharply crop a trunk, branch or other prop at the upper canvas edge. Keep heads/beaks fully inside the top edge. Include this constraint in all future generation prompts and visual reviews.
- Classic primary illustrations for compact contexts show ONLY the bird, without branches, perches, rocks, plants, water, food, ground or shadows, on transparent background. Include the whole bird and natural feet. This applies to all existing and future classics; dynamic/detail scenes may retain props. Future primary imports require composition: bird-only and a hash-bound anatomyReview.noProps attestation.
- Anatomy QA is mandatory for every new or revised image, at individual full-image resolution before installation. Trace exactly two wings from their shoulder attachments: an open near-side wing replaces its folded silhouette; never leave a second folded wing on that flank. One head and one beak only. In a straight rear view the bill points away and is normally hidden; never mirror bills or eyes onto both sides. Use these constraints explicitly in generation/edit prompts. Record a hash-bound visual review in the import mapping; file/alpha checks alone do not establish anatomical correctness. If any view is ambiguous, regenerate or simplify the pose before accepting. These human/model visual checks reduce errors but cannot guarantee anatomical accuracy.
- Flight illustrations (slide 4) must ALWAYS use a centered ventral view directly from below: head/bill toward the top, tail toward the bottom, both wings spread left/right at approximately equal height. Show species-correct belly and underwing plumage. Keep the whole bird inside the canvas on transparent background. This replaces the former right-facing side/three-quarter flight pose for all existing and future species. Classic thumbnails still face right. Use `projection: centered-ventral-spread` in the artwork import/manifest.
- Every species needs five separate media roles: classic right-facing illustration for compact contexts, dynamic species-detail hero, front illustration (slide 2), rear illustration (slide 3), and a flight illustration (slide 4). Detail slides must not reuse the classic thumbnail. Missing roles must use explicit placeholders. Dynamic compositions should be species-specific (for example fish-carrying kingfisher, pecking woodpecker, hovering kestrel); not every bird needs to be moving.
- All classic primary bird illustrations must face right throughout the app. Review each new asset and use the shared `PrimaryBirdImage` renderer for consistent orientation; retain original source files and record any display reflection in the artwork manifest.

## Implementation rules
- SwiftUI first, with lightweight feature-oriented structure and protocol-based services. Use SwiftData for user-owned records if it meets sync/migration needs.
- Keep species IDs stable and independent of translated names. Record taxonomy version.
- Treat photo/sound identifications as suggestions until the user confirms.
- Never silently overwrite observations or drop imported data. Support export and tests.
- No hardcoded credentials, tokens, or user-private location data in source control.
- No unlicensed fonts, photos, sounds, models or scraped image assets.
- Google Images action: open a dismissible scrolling search view where allowed, or offer a browser fallback; do not scrape Google or assume an official Google Images API.
- Network-dependent features must have clear loading, error, empty and offline states.
- Request location, microphone and photo permissions only when relevant.
- Keep UI copy in Dutch by default; store both Dutch and English bird names.

## Workflow and verification
- Before coding: inspect repository, read brief, identify target files, outline a short plan.
- After coding: summarize changed files, behavior, and known limitations.
- Run available formatting, static checks and tests; report exact commands and results.
- **Do not claim an iOS build or simulator test passed unless Xcode actually ran.** During iPad/Codex Cloud work without macOS, state that native compilation remains unverified.
- Make small commits/PRs with descriptive messages. Do not modify unrelated files.
- If reference images are missing, request upload or use an explicitly labeled placeholder. Do not hallucinate assets from previous ChatGPT conversations.
- Ask before choosing paid services, changing taxonomic authority, or introducing dependencies with uncertain licenses.

## Phase 1 task definition
Build the kingfisher species-detail SwiftUI screen, reusable design tokens, tab component, facts component, and a minimal local observation form. Use a small mock species repository and add unit tests for basic models and observation/lifelist logic. Add a README documenting how to open and build in Xcode later, including prerequisites and unverified items.

## Definition of done for each PR
- Changes are scoped and documented.
- No secrets or copyright-problematic assets added.
- Accessible labels and sensible layout at multiple text sizes.
- Tests added for meaningful logic changes.
- Honest verification notes; no invented test results.


## Global artwork production scope
Latest user override, 23 November 2026: produce only missing primary and dynamic
roles for now. Front, rear and flight are deferred, including for partial sets.
Keep existing approved assets and the five-role model. This supersedes the
five-role production scope below until the user resumes the deferred views.

The user authorized completing all five illustration roles for all catalog
species, using habitat-grouped, reviewable batches, without asking approval for
each batch. Keep existing species/observation IDs, the shared style and the
centered ventral flight standard. Refresh Scripts/illustration_production_queue.py
after each batch. The queue is an inventory, not a background execution service;
never imply all remaining images are being generated after a turn ends.

## Latest feedback — milestones and local maps, 24 November 2026

Milestones use a fullscreen olive/light overlay, tap anywhere to dismiss with no
close icon. Baseline existing history and suppress import/restore replays.
Discover report badges open read-only native maps for both logged and unlogged
species, with source links beside the close button. Never invent observer names
or times that providers omit. Session/country detail maps show all their valid
log points; the general Countries map still shows each species' first log.
The logbook home filter uses a privately configured local home point and 150m
radius; no private addresses in source control. Local bird settings use a
fullscreen back/header flow. See Docs/MILESTONES_AND_REPORT_MAPS.md.
