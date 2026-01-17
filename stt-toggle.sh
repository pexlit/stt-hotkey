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
