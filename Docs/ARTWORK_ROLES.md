# Species illustration roles

## Current production priority — 23 November 2026

The user has deferred front, rear and flight production. Generate only missing
primary and dynamic illustrations for now, including when finishing partially
started species. Preserve all existing approved views and the five-role asset
model. The three other views will be added later; do not generate them until
the user resumes that phase. Queue `activeMissingRoles` tracks this two-role
phase separately from the full five-role inventory.

Latest user direction: 19 November 2026. All five assets are illustrations, including the flight view.

| Role | Asset suffix | Use |
| --- | --- | --- |
| Classic | `-primary` | Compact discovery/logbook/session rows, species picker, observation form and map marker. Always faces right. |
| Dynamic | `-dynamic` | Species-detail slide 1. Distinctive behaviour, posture or composition; not necessarily moving. |
| Front | `-front` | Species-detail slide 2. Front view. |
| Rear | `-rear` | Species-detail slide 3. Rear view. |
| Flight | `-flight` | Species-detail slide 4. Illustration in flight. |

Stable species IDs prefix every asset. `SpeciesMediaRole.detailSlides` controls the fixed dynamic/front/rear/flight order. The classic thumbnail renderer and its existing direction corrections remain separate; dynamic compositions are not automatically mirrored or substituted for thumbnails. Missing slides remain clearly labeled placeholders instead of falling back to the wrong role. Page indicator buttons and VoiceOver follow the new order.

Two original dynamic examples are bundled: kingfisher carrying a fish and great spotted woodpecker pecking at a birch trunk. Source paths and generation provenance are in `Resources/ArtworkManifest.json`. They face right and retain the established ivory natural-history style. The classic six sample portraits remain unchanged. User approval and independent anatomy/field-mark review are pending for generated artwork.

Current coverage: classic portraits 6/6, dynamic heroes 2/6, front/rear/flight illustrations 0/6 each. The remaining artwork has not been created and is explicitly shown as pending. Kestrel hovering is recorded as a future composition example, not a new taxonomy/catalog entry. No photographs or external media were added.

Verification: `git diff --check`, Swift tree-sitter syntax scan, JSON manifest parsing and existence checks for all eight referenced illustration assets passed. No source files were added to the Xcode project; its asset catalog automatically includes the two new image sets. Native rendering, carousel sizing, original thumbnail retention and VoiceOver order must still be checked with Xcode.
