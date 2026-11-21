# AGENTS.md — Codex instructions for Birding Companion

You are working on a private, non-commercial, native iPhone birdwatching app. `PROJECT_BRIEF.md` is the product and design source of truth. Read it before making architectural or UI decisions.

## Goals and priorities
1. Deliver a usable, reliable offline-first observation log and global illustrated bird guide.
2. Match the approved kingfisher species-detail visual direction closely, without sacrificing accessibility or responsiveness.
3. Preserve data integrity, privacy, and exportability.
4. Keep integrations (eBird, BirdNET, photo ID, CloudKit) modular, licensed, and testable.
5. Prefer incremental, reviewable changes over broad speculative rewrites.

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

## Latest approved artwork direction
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
The user authorized completing all five illustration roles for all catalog
species, using habitat-grouped, reviewable batches, without asking approval for
each batch. Keep existing species/observation IDs, the shared style and the
centered ventral flight standard. Refresh Scripts/illustration_production_queue.py
after each batch. The queue is an inventory, not a background execution service;
never imply all remaining images are being generated after a turn ends.
