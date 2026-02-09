#!/usr/bin/env bash
#
# transcribe.sh - Transcribe audio file using Whisper
#
# Usage:
#   transcribe.sh <audio-file> [model]
#
# Arguments:
#   audio-file: Path to audio file (WAV, MP3, etc.)
#   model: Whisper model (default: base)
#
# Returns:
#   Transcription text on stdout
#   Exit code 0 on success, 1 on failure
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/common.sh"

# Config
WHISPER_VENV="${WHISPER_VENV:-$HOME/code/openai-whisper/.venv}"
WHISPER_MODEL="${1:-base}"

# Validate input
if [[ -z "$1" ]]; then
    log_error "Usage: transcribe.sh <audio-file> [model]"
    exit 1
fi

AUDIO_FILE="$1"
WHISPER_MODEL="${2:-base}"

if [[ ! -f "$AUDIO_FILE" ]]; then
    log_error "Audio file not found: $AUDIO_FILE"
    exit 1
fi

if [[ ! -d "$WHISPER_VENV" ]]; then
    log_error "Whisper venv not found: $WHISPER_VENV"
    log_error "Set WHISPER_VENV environment variable or install Whisper at default location"
    exit 1
fi

# Transcribe
WHISPER_BIN="$WHISPER_VENV/bin/whisper"
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

log_info "Transcribing with Whisper (model: $WHISPER_MODEL)..."

"$WHISPER_BIN" "$AUDIO_FILE" \
    --model "$WHISPER_MODEL" \
    --language en \
    --output_dir "$TEMP_DIR" \
    --output_format txt \
    > /dev/null 2>&1

# Read transcription
AUDIO_BASENAME=$(basename "$AUDIO_FILE" | sed 's/\.[^.]*$//')
TXT_FILE="$TEMP_DIR/${AUDIO_BASENAME}.txt"

if [[ -f "$TXT_FILE" ]]; then
    cat "$TXT_FILE"
    exit 0
else
    log_error "Transcription failed - output file not found"
    exit 1
fi
