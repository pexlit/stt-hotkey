# STT Hotkey

Press a key to record your voice, press again to transcribe and paste. Uses OpenAI's Whisper for accurate offline speech recognition.

## Features

- Press `Menu` key to start/stop recording
- Automatic transcription with Whisper AI (runs locally)
- Pastes directly at cursor
- Works in terminals and browsers
- No cloud - everything runs on your machine

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/pexlit/stt-hotkey/main/install.sh | bash
```

Or run locally:
```bash
git clone https://github.com/pexlit/stt-hotkey.git
cd stt-hotkey
bash install.sh
```

## Usage

1. Press **Menu** key → starts recording
2. Speak
3. Press **Menu** key again → transcribes and pastes

First use downloads the Whisper model (~140MB).

## Configuration

Edit `~/.local/bin/stt-toggle.sh`:

- **Model**: Change `--model base` to `tiny` (faster) or `small`/`medium` (more accurate)
- **Language**: Change `--language en` to your language code (`nl`, `de`, etc.)

## Troubleshooting

**Menu key doesn't work after install?** Log out and back in for GNOME to register the shortcut.

Errors are shown as notifications. For details, check the log:
```bash
cat /tmp/stt-hotkey.log
```

## Uninstall

```bash
rm -f ~/.local/bin/stt-toggle.sh
rm -rf ~/.local/share/stt-hotkey-venv
gsettings reset org.gnome.settings-daemon.plugins.media-keys custom-keybindings
```

## License

MIT
