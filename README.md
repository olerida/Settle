# Settle

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-007AFF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white)](Settle)
[![License: MIT](https://img.shields.io/badge/license-MIT-2EA44F)](LICENSE)

Save and restore macOS window layouts directly from the menu bar.

Switch between work, coding, meetings, and study setups in seconds. Settle reopens apps, restores each window's size and position, and leaves unrelated windows alone unless you choose otherwise.

![Settle menu preview](web/public/settle-preview.png)

## Highlights

- Native macOS app built with `SwiftUI` and `AppKit`
- Menu bar workflow with a resizable panel UI
- Automatic panel height that fits saved layouts up to 75% of the active screen
- Save named layouts for the current desktop
- Restore layouts by reopening apps and repositioning windows
- Native Settings for launch behavior, permissions, and future preferences
- Optional launch at login using the macOS login item service
- Optional automatic restore of an explicitly selected default layout at macOS login
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
- Screen Recording permission is optional and used only for layout preview thumbnails
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

Automatic layout restore also requires Accessibility permission. A signed embedded login helper starts Settle at login and requests the restore once; opening Settle manually never restores the default layout. If access is unavailable during login restore, the restore is skipped without changing the selected default layout.

Settle does not use Accessibility to read document contents, passwords, browser page contents, or keystrokes.

Screen Recording access is used only to capture layout preview thumbnails. Settle does not capture system audio.

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

Current documented release: `v1.4.0`

See [`CHANGELOG.md`](CHANGELOG.md) for release history.

## Development notes

- The app persists layouts locally as versioned JSON.
- Releases are published as signed DMG assets on GitHub.
- The Homebrew cask is maintained separately in `~/Documents/homebrew-tap`.
- Backlog work is tracked in GitHub Issues, not in repository TODO files.

## License

Settle is distributed under the terms of the [`MIT License`](LICENSE).
