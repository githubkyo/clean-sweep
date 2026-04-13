# CleanSweep

[日本語](README.ja.md) | English

A native macOS storage cleaner for developers. Detects hidden large files from Docker, Xcode, npm, Gradle, AI tools, and more — and safely removes them.

## Features

- **Developer-tool focused** — Docker, Xcode DerivedData, npm/yarn/pnpm caches, Gradle, Flutter, CocoaPods
- **AI tools support** — Claude Code temp files, Claude Desktop, Cursor data
- **Deep system scan** — APFS snapshots, /private/tmp, system caches
- **Safety ratings** — Color-coded 3-level system: Safe / Caution / Danger
- **Trash by default** — Moves to Trash (recoverable from Finder)
- **sudo support** — For APFS snapshots, copies the command to clipboard
- **Localized** — Japanese and English

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.2+ / Xcode 16+
- Full Disk Access permission (recommended)

## Installation

### Homebrew (planned)
```bash
brew install --cask cleansweep
```

### DMG Download
Download the latest `.dmg` from the [Releases](../../releases) page.

### Build from Source
```bash
git clone https://github.com/your-username/clean-sweep.git
cd clean-sweep
make run
```

## Usage

1. Launch CleanSweep
2. Grant Full Disk Access (first time only — in-app guide provided)
3. Click "Scan"
4. Safe items are auto-selected
5. Review and click "Trash" to clean up

## Build

```bash
make build    # Release build
make test     # Run tests
make app      # Create .app bundle
make sign     # Ad-hoc signing
make dmg      # Create DMG
make run      # Build & launch
```

## Scan Targets

| Category | Targets | Default Safety |
|----------|---------|----------------|
| Docker | Unused images/volumes/build cache | Safe |
| Xcode | DerivedData, Archives, DeviceSupport, Simulator | Safe–Caution |
| Node.js | npm/yarn/pnpm caches, node_modules | Safe |
| Flutter | pub-cache, CocoaPods | Safe |
| Gradle | .gradle cache | Safe |
| AI Tools | Claude Code temp files, Claude Desktop | Safe–Caution |
| System Caches | Chrome, Homebrew, VS Code, pip | Safe |
| Temp Files | /private/tmp (over 100MB) | Caution |
| APFS Snapshots | OS update snapshots | Caution |

## License

MIT License
