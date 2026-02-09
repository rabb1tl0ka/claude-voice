#!/usr/bin/env bash
#
# listen.sh - Record desktop audio output in the background
#
# Usage:
#   listen.sh start <session-id> <vault-path>
#   listen.sh stop <session-id>
#   listen.sh status <session-id>
#   listen.sh list
#
# Session metadata stored in: /tmp/claude-listen-<session-id>.json
# Audio recorded to: /tmp/claude-listen-<session-id>.wav
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

SESSION_DIR="/tmp/claude-listen-sessions"
mkdir -p "$SESSION_DIR"

# Parse command
COMMAND="${1:-}"
SESSION_ID="${2:-}"

case "$COMMAND" in
    start)
        VAULT_PATH="${3:-}"

        if [[ -z "$SESSION_ID" ]] || [[ -z "$VAULT_PATH" ]]; then
            log_error "Usage: listen.sh start <session-id> <vault-path>"
            exit 1
        fi

        # Normalize vault path
        VAULT_PATH="$(readlink -f "$VAULT_PATH")"

        if [[ ! -d "$VAULT_PATH" ]]; then
            log_error "Vault directory not found: $VAULT_PATH"
            exit 1
        fi

        SESSION_FILE="$SESSION_DIR/${SESSION_ID}.json"
        AUDIO_FILE="/tmp/claude-listen-${SESSION_ID}.wav"
        PID_FILE="/tmp/claude-listen-${SESSION_ID}.pid"

        # Check if session already exists
        if [[ -f "$SESSION_FILE" ]]; then
            log_error "Session already exists: $SESSION_ID"
            exit 1
        fi

        # Detect audio sink monitor
        log_info "Detecting audio output..."
        MONITOR_SOURCE=$("$SCRIPT_DIR/lib/detect-audio-sink.sh")

        if [[ -z "$MONITOR_SOURCE" ]]; then
            log_error "Could not detect audio output sink"
            exit 1
        fi

        log_info "Recording from: $MONITOR_SOURCE"

        # Start recording in background
        parecord --file-format=wav --channels=2 --rate=48000 \
            --device="$MONITOR_SOURCE" "$AUDIO_FILE" &

        RECORD_PID=$!

        # Save PID
        echo "$RECORD_PID" > "$PID_FILE"

        # Wait a moment to verify recording started
        sleep 0.5

        if ! kill -0 "$RECORD_PID" 2>/dev/null; then
            log_error "Recording failed to start"
            rm -f "$PID_FILE"
            exit 1
        fi

        # Save session metadata
        cat > "$SESSION_FILE" << EOF
{
  "session_id": "$SESSION_ID",
  "vault": "$VAULT_PATH",
  "start_time": "$(date -Iseconds)",
  "pid": $RECORD_PID,
  "audio_file": "$AUDIO_FILE",
  "monitor_source": "$MONITOR_SOURCE"
}
EOF

        log_success "Recording started (session: $SESSION_ID)"
        notify "🔴 Recording" "Desktop audio capture started"

        echo "$SESSION_FILE"
        ;;

    stop)
        if [[ -z "$SESSION_ID" ]]; then
            log_error "Usage: listen.sh stop <session-id>"
            exit 1
        fi

        SESSION_FILE="$SESSION_DIR/${SESSION_ID}.json"
        PID_FILE="/tmp/claude-listen-${SESSION_ID}.pid"

        if [[ ! -f "$SESSION_FILE" ]]; then
            log_error "Session not found: $SESSION_ID"
            exit 1
        fi

        # Read PID
        if [[ -f "$PID_FILE" ]]; then
            RECORD_PID=$(cat "$PID_FILE")

            # Stop recording
            if kill -0 "$RECORD_PID" 2>/dev/null; then
                kill "$RECORD_PID" 2>/dev/null || true
                wait "$RECORD_PID" 2>/dev/null || true
            fi

            rm -f "$PID_FILE"
        fi

        # Read session metadata
        AUDIO_FILE=$(jq -r '.audio_file' "$SESSION_FILE")

        if [[ ! -f "$AUDIO_FILE" ]]; then
            log_error "Audio file not found: $AUDIO_FILE"
            rm -f "$SESSION_FILE"
            exit 1
        fi

        log_success "Recording stopped"
        notify "⏹️ Recording Stopped" "Processing transcription..."

        # Return audio file path
        echo "$AUDIO_FILE"
        ;;

    status)
        if [[ -z "$SESSION_ID" ]]; then
            log_error "Usage: listen.sh status <session-id>"
            exit 1
        fi

        SESSION_FILE="$SESSION_DIR/${SESSION_ID}.json"

        if [[ ! -f "$SESSION_FILE" ]]; then
            echo "not_found"
            exit 1
        fi

        PID=$(jq -r '.pid' "$SESSION_FILE")

        if kill -0 "$PID" 2>/dev/null; then
            echo "recording"
        else
            echo "stopped"
        fi
        ;;

    list)
        if [[ ! -d "$SESSION_DIR" ]] || [[ -z "$(ls -A "$SESSION_DIR")" ]]; then
            echo "No active sessions"
            exit 0
        fi

        for session_file in "$SESSION_DIR"/*.json; do
            if [[ -f "$session_file" ]]; then
                SESSION_ID=$(basename "$session_file" .json)
                VAULT=$(jq -r '.vault' "$session_file")
                START_TIME=$(jq -r '.start_time' "$session_file")
                PID=$(jq -r '.pid' "$session_file")

                if kill -0 "$PID" 2>/dev/null; then
                    STATUS="🔴 recording"
                else
                    STATUS="⏹️ stopped"
                fi

                echo "[$STATUS] $SESSION_ID - $(basename "$VAULT") - started $START_TIME"
            fi
        done
        ;;

    *)
        log_error "Usage: listen.sh {start|stop|status|list}"
        exit 1
        ;;
esac
