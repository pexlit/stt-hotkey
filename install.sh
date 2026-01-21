#!/bin/bash
# STT Hotkey Installer - Speech-to-Text with Whisper
# https://github.com/pexlit/stt-hotkey
#
# Run: curl -fsSL https://raw.githubusercontent.com/pexlit/stt-hotkey/main/install.sh | bash

set -e

echo "=== STT Hotkey Installer ==="
echo "https://github.com/pexlit/stt-hotkey"
echo ""

# Check for Ubuntu/Debian with GNOME
if ! command -v gsettings &> /dev/null; then
    echo "ERROR: This script requires GNOME desktop environment."
    exit 1
fi

# Install system dependencies
echo "[1/4] Installing system dependencies..."
sudo apt update -qq
sudo apt install -y -qq ffmpeg xclip libnotify-bin python3-venv bc

# Create virtual environment
echo "[2/4] Creating Python virtual environment..."
python3 -m venv ~/.local/share/stt-hotkey-venv

# Install Whisper
echo "[3/4] Installing Whisper (this may take a few minutes)..."
~/.local/share/stt-hotkey-venv/bin/pip install -q openai-whisper

# Download and install the toggle script
echo "[4/4] Installing toggle script..."
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/pexlit/stt-hotkey/main/stt-toggle.sh -o ~/.local/bin/stt-toggle.sh
chmod +x ~/.local/bin/stt-toggle.sh

# Clean up old installation
rm -f ~/.local/bin/whisper-toggle.sh
rm -rf ~/.local/share/whisper-dictation-venv
rm -f /tmp/whisper-recording.*

# Set up GNOME keybinding
echo "Configuring keyboard shortcut (Pause key)..."
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/']"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ name 'STT Hotkey'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ command "$HOME/.local/bin/stt-toggle.sh"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ binding 'Pause'

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Usage:"
echo "  1. Press Pause key (top right of keyboard) → starts recording"
echo "  2. Speak your text"
echo "  3. Press Pause again → transcribes and copies to clipboard"
echo "  4. Paste with Ctrl+V"
echo ""
echo "First transcription will download the Whisper model (~140MB)."
echo ""
echo "To change the hotkey, see README Configuration section."
echo ""
echo "Files:"
echo "  - Last recording: /tmp/stt-hotkey-recording.wav"
echo "  - Log file: /tmp/stt-hotkey.log"
