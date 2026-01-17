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
echo "[1/5] Installing system dependencies..."
sudo apt update -qq
sudo apt install -y -qq ffmpeg xclip xdotool libnotify-bin python3-venv

# Create virtual environment
echo "[2/5] Creating Python virtual environment..."
python3 -m venv ~/.local/share/stt-hotkey-venv

# Install Whisper
echo "[3/5] Installing Whisper (this may take a few minutes)..."
~/.local/share/stt-hotkey-venv/bin/pip install -q openai-whisper

# Create the toggle script
echo "[4/5] Creating toggle script..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/stt-toggle.sh << 'SCRIPT_EOF'
#!/bin/bash
# STT Hotkey - Toggle recording with Menu key
# https://github.com/pexlit/stt-hotkey

LOCK_FILE="/tmp/stt-hotkey-recording.lock"
AUDIO_FILE="/tmp/stt-hotkey-recording.wav"
LOG_FILE="/tmp/stt-hotkey.log"
WHISPER_BIN="$HOME/.local/share/stt-hotkey-venv/bin/whisper"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"; }

check_deps() {
    local missing=""
    command -v ffmpeg &>/dev/null || missing="ffmpeg"
    command -v xclip &>/dev/null || missing="${missing:+$missing, }xclip"
    command -v xdotool &>/dev/null || missing="${missing:+$missing, }xdotool"
    [ -f "$WHISPER_BIN" ] || missing="${missing:+$missing, }whisper (run installer again)"
    if [ -n "$missing" ]; then
        notify-send -u critical -t 10000 "STT Hotkey: Missing" "$missing"
        log "ERROR: Missing: $missing"
        exit 1
    fi
}

if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    rm -f "$LOCK_FILE"
    log "Stopping recording (PID: $PID)"

    [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null && kill -INT "$PID" 2>/dev/null
    for i in {1..20}; do kill -0 "$PID" 2>/dev/null || break; sleep 0.1; done
    pkill -INT -f "ffmpeg.*stt-hotkey-recording" 2>/dev/null
    sleep 0.3

    if [ -f "$AUDIO_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")
        log "Audio file size: $FILE_SIZE bytes"
        if [ "$FILE_SIZE" -lt 1000 ]; then
            notify-send -t 5000 "STT Hotkey" "Recording too short - speak longer"
            log "ERROR: File too small ($FILE_SIZE bytes)"
            rm -f "$AUDIO_FILE"
            exit 1
        fi
    else
        notify-send -u critical -t 5000 "STT Hotkey" "No audio recorded. Check microphone."
        log "ERROR: No audio file"
        exit 1
    fi

    notify-send -t 2000 "STT Hotkey" "Transcribing..."
    CONTEXT=$(xclip -selection primary -o 2>/dev/null | head -c 500)

    WHISPER_OUTPUT=$("$WHISPER_BIN" "$AUDIO_FILE" --model base --language en --output_format txt --output_dir /tmp 2>&1)
    WHISPER_EXIT=$?
    [ $WHISPER_EXIT -ne 0 ] && log "Whisper error ($WHISPER_EXIT): $WHISPER_OUTPUT"

    TXT_FILE="/tmp/stt-hotkey-recording.txt"
    if [ -f "$TXT_FILE" ]; then
        TEXT=$(cat "$TXT_FILE")
        rm -f "$TXT_FILE"
        log "Transcribed: ${TEXT:0:100}"
        if [ -n "$TEXT" ]; then
            printf '%s' "$TEXT" | xclip -selection clipboard
            sleep 0.1
            xdotool key --clearmodifiers ctrl+shift+v
            notify-send -t 2000 "STT Hotkey" "${TEXT:0:80}"
        else
            notify-send -t 3000 "STT Hotkey" "No speech detected"
        fi
    else
        notify-send -u critical -t 5000 "STT Hotkey" "Transcription failed. Check: $LOG_FILE"
        log "ERROR: No output. Whisper: $WHISPER_OUTPUT"
    fi
    rm -f "$AUDIO_FILE"
else
    log "Starting recording..."
    check_deps

    pkill -INT -f "ffmpeg.*stt-hotkey-recording" 2>/dev/null
    rm -f "$AUDIO_FILE" "$LOCK_FILE"

    FFMPEG_ERR=$(mktemp)
    ffmpeg -y -f pulse -i default -ar 16000 -ac 1 -t 120 "$AUDIO_FILE" 2>"$FFMPEG_ERR" &
    FFMPEG_PID=$!

    for i in {1..10}; do [ -f "$AUDIO_FILE" ] && break; sleep 0.1; done

    if kill -0 "$FFMPEG_PID" 2>/dev/null; then
        echo "$FFMPEG_PID" > "$LOCK_FILE"
        notify-send -t 1500 "STT Hotkey" "Recording... Press Menu to stop"
        log "Recording started (PID: $FFMPEG_PID)"
    else
        ERR=$(cat "$FFMPEG_ERR" 2>/dev/null)
        log "ERROR: ffmpeg failed: $ERR"
        if echo "$ERR" | grep -qi "pulse"; then
            notify-send -u critical -t 8000 "STT Hotkey" "Microphone error. Check Settings → Sound"
        else
            notify-send -u critical -t 8000 "STT Hotkey" "Recording failed. Check: $LOG_FILE"
        fi
    fi
    rm -f "$FFMPEG_ERR"
fi
SCRIPT_EOF
chmod +x ~/.local/bin/stt-toggle.sh

# Clean up old installation
rm -f ~/.local/bin/whisper-toggle.sh
rm -rf ~/.local/share/whisper-dictation-venv
rm -f /tmp/whisper-recording.*

# Set up GNOME keybinding (reset first to avoid conflicts)
echo "[5/5] Configuring keyboard shortcut (Menu key)..."
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/']"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ name 'STT Hotkey'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ command "$HOME/.local/bin/stt-toggle.sh"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/stt-hotkey/ binding 'Menu'

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Press the Menu key (between right Ctrl and Alt) to start recording."
echo "Press again to transcribe and paste."
echo ""
echo "First transcription will download the Whisper model (~140MB)."
echo ""
echo "Note: You may need to log out and back in for the shortcut to work."
