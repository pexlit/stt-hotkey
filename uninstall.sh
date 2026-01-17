#!/bin/bash
# STT Hotkey Uninstaller
# https://github.com/pexlit/stt-hotkey

echo "=== STT Hotkey Uninstaller ==="

# Remove script
rm -f ~/.local/bin/stt-toggle.sh
rm -f ~/.local/bin/whisper-toggle.sh  # old name
echo "Removed scripts"

# Remove venv
rm -rf ~/.local/share/stt-hotkey-venv
rm -rf ~/.local/share/whisper-dictation-venv  # old name
echo "Removed virtual environment"

# Remove keybindings
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]"
echo "Removed keyboard shortcuts"

# Clean up temp files
rm -f /tmp/stt-hotkey-recording.* /tmp/stt-hotkey.log
rm -f /tmp/whisper-recording.*  # old name
echo "Cleaned up temp files"

echo ""
echo "=== Uninstall complete ==="
