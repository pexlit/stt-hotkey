# STT Hotkey

Press a key to record your voice, press again to transcribe and paste. Uses OpenAI's Whisper for accurate offline speech recognition.

## Features

- Press `Pause` key to start/stop recording
- Automatic transcription with Whisper AI (runs locally)
- Copies transcribed text to clipboard
- Works in terminals and browsers
- No cloud - everything runs on your machine

## Requirements

- Ubuntu/Debian with GNOME desktop
- Microphone or headset (USB/Bluetooth/3.5mm)

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

1. Press **Pause** key (top right of keyboard) → starts recording
2. Speak your text
3. Press **Pause** again → transcribes and copies to clipboard
4. Paste with **Ctrl+V**

First use downloads the Whisper model (~140MB).

## Configuration

### Change Hotkey

Open Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts → STT Hotkey

Click on the current key binding and press your preferred key.

**Recommended keys** (no conflicts, easily accessible):
- `Pause` (default) - Top right of keyboard, rarely used by anything
- `Scroll Lock` - Next to Pause, available on most keyboards

### Adjust Transcription

Edit `~/.local/bin/stt-toggle.sh`:

- **Model**: Change `--model base` to `tiny` (faster) or `small`/`medium` (more accurate)
- **Language**: Change `--language en` to your language code (`nl`, `de`, etc.)

## Troubleshooting

**Menu key doesn't work after install?** Log out and back in for GNOME to register the shortcut.

**Want to hear what was recorded?** Play the last recording:
```bash
paplay /tmp/stt-hotkey-recording.wav
```

**Getting false transcriptions?** The script detects silence and low audio levels. Check your microphone levels in Settings → Sound → Input.

**No audio input devices found?** Make sure your microphone is connected and selected in Settings → Sound → Input.

Check the log for errors:
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
