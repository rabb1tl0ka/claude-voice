---
name: listen_start
description: Start recording desktop audio in the background
---

Start recording desktop audio output (speakers/headphones) in the background. Recording continues until you call `/listen_stop`.

**Usage:**
- `/listen_start` - Start recording desktop audio

**Use cases:**
- Recording a meeting or conference call
- Capturing a podcast or video you're watching
- Recording any audio playing on your system

**Note:** This records what's playing on your OUTPUT (speakers/headphones), not your microphone input.

---

## Implementation

```bash
#!/usr/bin/env bash

VOICE_TOOLS="$HOME/Bruno/code/voice-tools"
source "$VOICE_TOOLS/lib/common.sh"

# Detect vault (walks up tree to find vault root)
VAULT_DIR=$("$VOICE_TOOLS/lib/detect-vault.sh" 2>/dev/null) || true

if [[ -z "$VAULT_DIR" ]]; then
    # No vault found - use current directory (silent default)
    VAULT_DIR="$(pwd)"
    log_info "Not in a vault - will save to current directory"
fi

# Create inbox if it doesn't exist
INBOX_DIR="$VAULT_DIR/inbox"
if [[ ! -d "$INBOX_DIR" ]]; then
    mkdir -p "$INBOX_DIR"
    log_info "Created inbox directory: $INBOX_DIR"
fi

# Generate session ID
SESSION_ID=$(get_timestamp)

# Start recording
SESSION_FILE=$("$VOICE_TOOLS/listen.sh" start "$SESSION_ID" "$VAULT_DIR")

if [[ $? -eq 0 ]]; then
    VAULT_NAME=$(basename "$VAULT_DIR")
    log_success "Recording desktop audio to $VAULT_NAME"
    echo ""
    echo "Session ID: $SESSION_ID"
    echo ""
    echo "Use /listen_stop to finish recording and transcribe."
    notify "🔴 Recording" "Desktop audio → $VAULT_NAME"
else
    log_error "Failed to start recording"
    exit 1
fi
```

After the bash script runs successfully, inform the user that recording has started and they should use `/listen_stop` when done.
