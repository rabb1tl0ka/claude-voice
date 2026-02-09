---
name: listen_stop
description: Stop recording, transcribe, summarize, and save
---

Stop the active desktop audio recording, transcribe it with Whisper, generate a summary, and save both to the vault's inbox.

**Usage:**
- `/listen_stop` - Stop recording and process

**Output format:**
- File: `inbox/listen-YYYY-MM-DD-HHMMSS.md`
- Contains: AI summary + full transcript

---

## Implementation

```bash
#!/usr/bin/env bash

VOICE_TOOLS="$HOME/Bruno/code/voice-tools"
source "$VOICE_TOOLS/lib/common.sh"

# List active sessions
SESSION_DIR="/tmp/claude-listen-sessions"

if [[ ! -d "$SESSION_DIR" ]] || [[ -z "$(ls -A "$SESSION_DIR" 2>/dev/null)" ]]; then
    log_error "No active recording sessions found"
    echo ""
    echo "Start a recording with /listen_start first"
    exit 1
fi

# Find active sessions
SESSIONS=($(ls "$SESSION_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/.json$//'))

if [[ ${#SESSIONS[@]} -eq 0 ]]; then
    log_error "No active recording sessions"
    exit 1
elif [[ ${#SESSIONS[@]} -eq 1 ]]; then
    SESSION_ID="${SESSIONS[0]}"
else
    # Multiple sessions - ask which one
    log_warn "Multiple recording sessions found. Which one to stop?"
    echo ""
    for i in "${!SESSIONS[@]}"; do
        SESSION_FILE="$SESSION_DIR/${SESSIONS[$i]}.json"
        VAULT=$(jq -r '.vault' "$SESSION_FILE")
        VAULT_NAME=$(basename "$VAULT")
        START_TIME=$(jq -r '.start_time' "$SESSION_FILE")
        echo "$((i+1))) ${SESSIONS[$i]} - $VAULT_NAME - started $START_TIME"
    done
    echo ""
    read -p "Choice [1-${#SESSIONS[@]}]: " choice

    if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#SESSIONS[@]} ]]; then
        SESSION_ID="${SESSIONS[$((choice-1))]}"
    else
        log_error "Invalid choice"
        exit 1
    fi
fi

SESSION_FILE="$SESSION_DIR/${SESSION_ID}.json"

# Read session metadata
VAULT_DIR=$(jq -r '.vault' "$SESSION_FILE")
START_TIME=$(jq -r '.start_time' "$SESSION_FILE")

log_info "Stopping recording session: $SESSION_ID"

# Stop recording
AUDIO_FILE=$("$VOICE_TOOLS/listen.sh" stop "$SESSION_ID")

if [[ ! -f "$AUDIO_FILE" ]]; then
    log_error "Failed to stop recording or audio file not found"
    exit 1
fi

# Get audio duration
DURATION_SEC=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null || echo "0")
DURATION_MIN=$(echo "scale=1; $DURATION_SEC / 60" | bc 2>/dev/null || echo "unknown")

log_info "Audio captured: ${DURATION_MIN} minutes"
log_info "Transcribing..."

# Transcribe
TRANSCRIPT=$("$VOICE_TOOLS/lib/transcribe.sh" "$AUDIO_FILE" "base")

if [[ -z "$TRANSCRIPT" ]]; then
    log_error "Transcription failed or no speech detected"
    rm -f "$AUDIO_FILE" "$SESSION_FILE"
    exit 1
fi

log_success "Transcription complete"

# Return metadata and transcript to Claude for summarization
echo "TRANSCRIPTION_COMPLETE"
echo "SESSION_ID: $SESSION_ID"
echo "VAULT: $VAULT_DIR"
echo "START_TIME: $START_TIME"
echo "DURATION_MIN: $DURATION_MIN"
echo "TRANSCRIPT_LENGTH: ${#TRANSCRIPT}"
echo "---TRANSCRIPT_START---"
echo "$TRANSCRIPT"
echo "---TRANSCRIPT_END---"

# Cleanup audio file
rm -f "$AUDIO_FILE"

# Keep session file for now - Claude will delete it after saving
```

After the bash script completes:

1. Parse the transcript from the output (between `---TRANSCRIPT_START---` and `---TRANSCRIPT_END---`)
2. Generate a summary:
   - Use Claude to analyze the transcript
   - Extract: key points, topics discussed, action items, important quotes
   - Keep it concise (5-10 bullet points)
3. Create the output file:
   ```markdown
   # Listen Session - YYYY-MM-DD HH:MM

   **Duration**: X.X minutes
   **Started**: YYYY-MM-DD HH:MM:SS
   **Source**: Desktop audio output

   ## Summary

   [AI-generated bullet points]
   - Key topic 1
   - Key topic 2
   - Action items

   ## Full Transcript

   [Complete Whisper transcription]
   ```
4. Save to: `{VAULT}/inbox/listen-YYYYMMDD-HHMMSS.md`
5. Clean up session file: `rm -f /tmp/claude-listen-sessions/{SESSION_ID}.json`
6. Report success to user with file path
