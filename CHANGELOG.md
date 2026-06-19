# Changelog

## v1.4.0

- Reworked the menu panel into a unified action bar, removed Quick Save, and kept the destructive Close All action at the far right.
- Added automatic panel height based on the saved layout list, capped at 75% of the active screen.
- Added a distinct, accessible highlight for the active layout in the current Space.

## v1.3.1

- Relicensed the repository from GPL-3.0 to MIT.
- Rewrote the main README in English with a more complete GitHub-facing project overview.

## v1.3.0

- Added a native About panel with app version, developer, website, and source links.
- Added a dedicated pinned layouts section with manual drag-to-reorder support.
- Improved panel modal behavior so overlays dim the background, close on outside click, and close on Escape without closing the whole Settle window.
- Fixed the About website link and prevented the initial keyboard focus ring from appearing on the header buttons when opening the menu.

## v1.2.1

- Fixed the distributed DMG so it now contains the correctly signed `com.olerida.Settle` app bundle.
- Rebuilt the release packaging flow to avoid broken Accessibility identity caused by unsigned or malformed app bundles.

## v1.2.0

- Replaced the old menu bar popup with a native resizable panel for a more reliable window list.
- Added window actions to quit every app, close extra windows, or minimize extra windows after restoring a layout.
- Added click-to-open layout snapshot previews from the saved layouts list.
- Improved active Space recognition so contextual actions and layout state follow the current desktop more accurately.

## v1.1.0

- Added a HUD overlay that shows the layout name when saving a layout.
- Added a HUD overlay that shows the layout name when restoring a layout.
- Added Space change detection that re-shows the layout name when returning to a desktop whose visible windows match a previously restored layout.

## v1.0.0

- Initial public release of Settle.
