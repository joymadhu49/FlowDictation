# FlowDictation

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

A lightweight macOS menu bar app for voice-to-text dictation powered by [Groq's Whisper API](https://console.groq.com). Hold a hotkey, speak, release — your words are transcribed and pasted at your cursor instantly.

## Features

- **Hold-to-dictate** — Hold your hotkey to record, release to transcribe
- **Instant paste** — Transcribed text is automatically inserted at your cursor position
- **Custom hotkeys** — Use preset keys (Option, Control, Fn) or set any custom key combination
- **Menu bar app** — Lives in the menu bar, no dock icon clutter
- **Fast transcription** — Powered by Groq's Whisper Large V3 Turbo (free tier available)
- **Sound feedback** — Adjustable audio cues for recording start, stop, and completion
- **Clipboard fallback** — Works with or without Accessibility permission
- **Zero dependencies** — Pure Swift, no external packages

## Requirements

- macOS 13.0 or later
- Free [Groq API key](https://console.groq.com)

## Installation

### Quick Install (Recommended)

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/joymadhu49/FlowDictation/main/scripts/install.sh | bash
```

This downloads, installs to Applications, and launches automatically. No Gatekeeper issues.

### Download DMG

1. Download `FlowDictation.dmg` from [Releases](https://github.com/joymadhu49/FlowDictation/releases)
2. Open the DMG, drag **FlowDictation** to **Applications**
3. Open **Terminal** and run:
   ```bash
   xattr -cr /Applications/FlowDictation.app
   ```
4. Open FlowDictation from Applications

> **Why step 3?** macOS blocks apps downloaded from the internet that aren't notarized by Apple. The `xattr -cr` command removes this block. This is standard for open-source macOS apps.

### Homebrew

```bash
brew tap joymadhu49/tap
brew install --cask flowdictation
```

### Build from Source

```bash
git clone https://github.com/joymadhu49/FlowDictation.git
cd FlowDictation
bash scripts/build-app.sh
open build/FlowDictation.app
```

## Setup

1. **Launch** the app — a microphone icon appears in the menu bar
2. **Set API key** — Click the mic icon, paste your Groq API key in the field
3. **Grant permissions** when prompted:
   - **Microphone** — for audio recording
   - **Accessibility** — for global hotkeys and auto-paste

## Usage

1. Place your cursor where you want text inserted
2. **Hold** your configured hotkey (default: Right Option)
3. **Speak** clearly
4. **Release** the hotkey — text is transcribed and pasted

## Hotkey Options

| Preset | Key |
|--------|-----|
| Option | Either Option key |
| Right Option | Right Option key only (default) |
| Control | Control key |
| Fn | Function key |
| Custom | Any key + modifier (e.g. `⌘⇧D`) |

Set your hotkey in **Settings > General > Hotkey**.

## Project Structure

```
FlowDictation/
├── Package.swift
├── Sources/FlowDictation/
│   ├── FlowDictationApp.swift          # App entry point
│   ├── AppDelegate.swift               # Menu bar setup
│   ├── Models/
│   │   └── DictationState.swift        # State & hotkey models
│   ├── Services/
│   │   ├── AudioRecorder.swift         # WAV recording (16kHz mono)
│   │   ├── GroqAPIClient.swift         # Whisper API client
│   │   ├── GlobalHotkeyManager.swift   # Global hotkey monitoring
│   │   ├── DictationManager.swift      # Core orchestrator
│   │   ├── TextInserter.swift          # Clipboard + paste simulation
│   │   └── SoundFeedback.swift         # Audio feedback
│   ├── Views/
│   │   ├── MenuBarView.swift           # Popover UI
│   │   └── SettingsView.swift          # Settings window
│   └── Resources/
│       ├── Info.plist
│       ├── AppIcon.icns
│       └── FlowDictation.entitlements
└── scripts/
    └── build-app.sh                    # Build .app bundle + DMG
```

## How It Works

1. Audio is recorded as 16kHz mono WAV (optimized for Whisper)
2. Sent to Groq's `whisper-large-v3-turbo` model via multipart upload
3. Transcribed text is placed on the clipboard
4. `Cmd+V` is simulated via System Events to paste at the cursor
5. Original clipboard contents are restored after 1 second

## License

MIT License — see [LICENSE](LICENSE) for details.
