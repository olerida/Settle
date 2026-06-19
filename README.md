# Settle

Settle is a native macOS menu bar app for saving and restoring window layouts on the current desktop.

It captures visible app windows, stores their size and position, and restores them later using macOS Accessibility APIs. The app is designed to stay conservative by default: windows outside the selected layout are left alone unless the user explicitly chooses contextual actions.

![Settle menu preview](web/public/settle-preview.png)

## Highlights

- Native macOS app built with `SwiftUI` and `AppKit`
- Menu bar workflow with a resizable panel UI
- Automatic panel height that fits saved layouts up to 75% of the active screen
- Save named layouts for the current desktop
- Restore layouts by reopening apps and repositioning windows
- Active layout highlighting that follows the current Space
- Unified action bar with primary save, contextual window actions, and a clearly separated destructive quit action
- Dedicated pinned layouts section with manual drag-to-reorder
- Layout snapshot previews inside the saved layouts list
- Contextual actions for restored layouts:
  - quit all apps
  - close non-layout windows
  - minimize non-layout windows
- Localized UI and website in:
  - English
  - Spanish
  - Catalan
  - French
  - German

## Requirements

- macOS `14.0+`
- Accessibility permission enabled for Settle
- Apple Silicon is the primary target, with universal macOS builds available in releases

## Install

### Direct download

Download the latest signed DMG from GitHub Releases:

- [Latest release](https://github.com/olerida/Settle/releases/latest)

### Homebrew

```bash
brew install --cask olerida/tap/settle
```

## Accessibility permission

Settle needs macOS Accessibility permission to:

- read visible window titles
- detect app windows
- move and resize windows during restore

Settle does not use Accessibility to read document contents, passwords, browser page contents, or keystrokes.

If you enable Accessibility and the app still shows the warning, quit and reopen Settle.

## Website

- Public site: [http://settle.titanolandia.es](http://settle.titanolandia.es)
- Hosting is built from the `web/` project with Astro

## Build from source

### App

Open [`Settle.xcodeproj`](Settle.xcodeproj) in Xcode and run the `Settle` scheme on `My Mac`.

Command-line debug build:

```bash
xcodebuild -project Settle.xcodeproj -scheme Settle -configuration Debug build
```

### Website

```bash
cd web
npm install
npm run build
```

## Project structure

- `Settle/`: macOS app source
- `SettleTests/`: unit tests
- `web/`: public Astro website
- `CHANGELOG.md`: release notes
- `AGENTS.md`: project-specific agent instructions

## Recent release

Current documented release: `v1.3.1`

See [`CHANGELOG.md`](CHANGELOG.md) for release history.

## Development notes

- The app persists layouts locally as versioned JSON.
- Releases are published as signed DMG assets on GitHub.
- The Homebrew cask is maintained separately in `~/Documents/homebrew-tap`.
- Backlog work is tracked in GitHub Issues, not in repository TODO files.

## License

Settle is distributed under the terms of the [`MIT License`](LICENSE).
