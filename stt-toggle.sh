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
    command -v bc &>/dev/null || missing="${missing:+$missing, }bc"
    [ -f "$WHISPER_BIN" ] || missing="${missing:+$missing, }whisper (run installer again)"
    if [ -n "$missing" ]; then
        notify-send -u critical -t 10000 "STT Hotkey: Missing" "$missing"
        log "ERROR: Missing: $missing"
        exit 1
    fi
}

check_audio_input() {
    log "Checking for audio input devices..."

    # Get list of pulse audio input sources
    local sources=$(ffmpeg -sources pulse 2>&1 | grep -E "^\s+[a-zA-Z]" | grep -v "monitor")

    if [ -z "$sources" ]; then
        local all_sources=$(ffmpeg -sources pulse 2>&1)
        notify-send -u critical -t 15000 "STT Hotkey: No Input Devices" \
            "No microphone found!\n\nSteps to fix:\n1. Connect microphone/headset\n2. Check Settings → Sound → Input\n3. For Bluetooth: Pair device first\n\nSee log: $LOG_FILE"
        log "ERROR: No audio input devices detected"
        log "Available sources: $all_sources"
        echo ""
        echo "================================"
        echo "STT Hotkey: No Input Devices Found"
        echo "================================"
        echo ""
        echo "No microphone or audio input device detected."
        echo ""
        echo "Available audio sources:"
        echo "$all_sources"
        echo ""
        echo "Steps to fix:"
        echo "1. Connect a microphone or headset (USB/Bluetooth/3.5mm)"
        echo "2. Go to Settings → Sound → Input"
        echo "3. Make sure an input device is selected and enabled"
        echo "4. For Bluetooth headsets: Pair them first in Settings → Bluetooth"
        echo ""
        echo "See log file for details: $LOG_FILE"
        echo ""
        exit 1
    else
        log "Audio input devices found: $sources"
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

        # Delete if greater than 100MB (104857600 bytes)
        if [ "$FILE_SIZE" -gt 104857600 ]; then
            log "Audio file deleted: size $FILE_SIZE bytes (>100MB)"
            rm -f "$AUDIO_FILE"
            notify-send -u critical -t 5000 "STT Hotkey" "Recording too large (>100MB) - deleted"
            exit 1
        fi

        if [ "$FILE_SIZE" -lt 1000 ]; then
            notify-send -t 5000 "STT Hotkey" "Recording too short - speak longer"
            log "ERROR: File too small ($FILE_SIZE bytes)"
            exit 1
        fi

        # Check audio levels to detect silence/noise
        AUDIO_STATS=$(ffmpeg -i "$AUDIO_FILE" -af "volumedetect" -f null /dev/null 2>&1 | grep "mean_volume")
        MEAN_VOLUME=$(echo "$AUDIO_STATS" | grep -oP "mean_volume: \K[-0-9.]+")

        log "Audio mean volume: $MEAN_VOLUME dB"

        # If mean volume is below -50 dB, it's likely just silence/noise
        if [ -n "$MEAN_VOLUME" ] && (( $(echo "$MEAN_VOLUME < -50" | bc -l) )); then
            notify-send -t 5000 "STT Hotkey" "Audio too quiet - speak louder or check mic"
            log "ERROR: Audio too quiet (mean volume: $MEAN_VOLUME dB)"
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
            # Copy to clipboard
            printf '%s' "$TEXT" | xclip -selection clipboard
            log "Copied to clipboard: ${TEXT:0:100}"

            notify-send -t 3000 "STT Hotkey" "📋 Copied: ${TEXT:0:60}"
        else
            notify-send -t 3000 "STT Hotkey" "No speech detected"
        fi
    else
        notify-send -u critical -t 5000 "STT Hotkey" "Transcription failed. Check: $LOG_FILE"
        log "ERROR: No output. Whisper: $WHISPER_OUTPUT"
    fi
else
    log "Starting recording..."
    check_deps
    check_audio_input

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
