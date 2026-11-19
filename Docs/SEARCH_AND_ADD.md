# Catalog search and add menu — 19 November 2026

Discover now has a top-right 44-point icon-only search action. It reveals a focused search field and catalog results in place of nearby recommendations; closing restores the existing nearby view and filter selection. It searches Dutch, English and scientific names, case/diacritic insensitively, trims whitespace and uses deterministic Dutch-name/ID ordering. Empty input browses all supplied catalog species. Results include logged and unlogged species independently of GPS, 10 km/30-day nearby rules or the logged-status filter. Classic right-facing thumbnails and reactive log-status badges remain visible; selecting a result opens its species detail page.

Global catalog coverage is **not yet available**. The current six sample species are explicitly labeled as sample search data. The search accepts an injected complete catalog and a completeness flag, but no production taxonomy, names dataset, license or stable-ID crosswalk has been selected or silently invented. Global coverage requires that approved data integration. Search interaction and data completeness are separate concerns.

The regular central plus now opens an ivory add page with three large rounded cards: Waarneming toevoegen, Sessie toevoegen and Doelstelling toevoegen. Bottom navigation stays visible. Observation opens a searchable species picker and the existing form; session opens completed-session entry; goal opens the existing checklist form. Cancelling returns to the previous screen (the species picker for an observation, then back to the menu). The menu back arrow, plus toggle or another navigation icon closes it. Species-page plus still directly opens that species' observation form. The khaki live-session play action and observation-map close action retain their existing priority.

Verification: `git diff --check`, Swift tree-sitter syntax checks and Xcode source membership validation. Three catalog-search tests cover multilingual matching, whitespace, diacritics, entire-catalog browsing, empty/no-match results and deterministic ties. Native compilation, keyboard focus, result navigation, returning from all three forms and the overlay/menu lifecycle must still be verified in Xcode. No worldwide catalog or native test result is claimed.


## Simplified search and add presentation
Search/close on Discover use the same 44-point circular target as species actions, with a light beige fill and no border. Open search replaces the large location title with “Zoek een vogelsoort”; closing restores “Vandaag in …”.

The add page has no visible heading or back arrow. Its three actions are 144-point circles, with 46-point fine icons only (bird, clock, checklist); descriptive Dutch VoiceOver labels remain. It scrolls on short displays. Only while this page is open, the regular bottom navigation row, its white background and top border are omitted. The 72-point central action stays in its original position and rotates to a close mark. Closing restores the previous page and full navigation. Full-screen forms keep their existing back controls.

This visual-only update was checked with Swift syntax parsing and `git diff --check`; actual circle sizing, focus and safe-area layout remain unverified without Xcode.


### Dark typographic add page
The latest add-page direction replaces the circular icon choices with three full-width, equal-height text regions: lowercase “waarneming”, “sessie” and “doelstelling” in 32-point Dynamic-Type-aware Fraunces, horizontally centered. The page and safe areas use charcoal, text is beige, and two faint 0.5-point inset rules separate the choices. Available content height excludes the reserved central close-button area; each region receives one third, with a 96-point minimum and scrolling on short/large-text layouts. The existing 72-point close control is beige with a fine dark cross. Navigation icons/background/border remain hidden on this page. All destination actions and accessibility labels remain intact. Native layout still requires Xcode verification.

The add-page titles now start with capitals: “Waarneming”, “Sessie”, “Doelstelling”. The two separator rules extend to both screen edges without horizontal insets.
