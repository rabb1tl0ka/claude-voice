#!/usr/bin/env bash
#
# voice-to-inbox.sh - Record voice note and save to inbox
#
# Usage:
#   ./voice-to-inbox.sh                    # saves as voice-2026-01-20-214530.md
#   ./voice-to-inbox.sh "my thought"       # saves as voice-my-thought.md
#

set -e

VAULT_DIR="$(dirname "$(readlink -f "$0")")"
INBOX_DIR="$VAULT_DIR/inbox"
WHISPER_VENV="$HOME/code/openai-whisper/.venv"
WHISPER_MODEL="base"
TEMP_AUDIO=$(mktemp --suffix=.wav)

# Cleanup on exit
cleanup() {
    rm -f "$TEMP_AUDIO" "${TEMP_AUDIO%.wav}.txt" "${TEMP_AUDIO%.wav}.srt" "${TEMP_AUDIO%.wav}.vtt" "${TEMP_AUDIO%.wav}.json"
}
trap cleanup EXIT

# Generate filename
if [[ -n "$1" ]]; then
    # Slugify the title: lowercase, replace spaces with dashes, remove special chars
    SLUG=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    FILENAME="voice-${SLUG}.md"
else
    FILENAME="voice-$(date +%Y-%m-%d-%H%M%S).md"
fi

OUTPUT_FILE="$INBOX_DIR/$FILENAME"

# Check if file exists
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "⚠️  File already exists: $FILENAME"
    echo "   Add a unique title or wait a second and retry"
    exit 1
fi

echo "🎙️  Recording... (press Enter to stop)"
echo ""

# Record audio using arecord (ALSA) - runs in background
arecord -f cd -t wav -q "$TEMP_AUDIO" &
RECORD_PID=$!

# Wait for Enter
read -r

# Stop recording
kill $RECORD_PID 2>/dev/null || true
wait $RECORD_PID 2>/dev/null || true

echo "⏳ Transcribing..."

# Activate venv and run whisper
source "$WHISPER_VENV/bin/activate"
whisper "$TEMP_AUDIO" --model "$WHISPER_MODEL" --language en --output_dir "$(dirname "$TEMP_AUDIO")" --output_format txt > /dev/null 2>&1

# Get transcription
TXT_FILE="${TEMP_AUDIO%.wav}.txt"
if [[ -f "$TXT_FILE" ]]; then
    TRANSCRIPTION=$(cat "$TXT_FILE")

    if [[ -z "$TRANSCRIPTION" ]]; then
        echo "⚠️  No speech detected"
        exit 1
    fi

    # Write to inbox
    cat > "$OUTPUT_FILE" << EOF
$TRANSCRIPTION
EOF

    echo "✅ Saved to inbox/$FILENAME"
    echo ""
    echo "--- Transcription ---"
    echo "$TRANSCRIPTION"
else
    echo "❌ Transcription failed"
    exit 1
fi
