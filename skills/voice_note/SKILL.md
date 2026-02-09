---
name: voice_note
description: Record a voice note to vault inbox
---

Record a voice note using automatic silence detection and save to a vault's inbox.

**Usage:**
- `/voice_note` - Record to current vault with timestamp
- `/voice_note "my note title"` - Record to current vault with custom title
- `/voice_note loka2026 "meeting notes"` - Record to specific vault with title

**Examples:**
- `/voice_note` → saves to `inbox/voice-20260208-143022.md`
- `/voice_note "bitcoin thoughts"` → saves to `inbox/voice-bitcoin-thoughts.md`
- `/voice_note bruno2brain-v3 "daily reflection"` → saves to bruno2brain-v3 inbox

---

## Implementation

```bash
#!/usr/bin/env bash

VOICE_TOOLS="$HOME/Bruno/code/voice-tools"
source "$VOICE_TOOLS/lib/common.sh"

# Parse arguments
ARG1="${1:-}"
ARG2="${2:-}"

VAULT_NAME=""
TITLE=""

# Determine if first arg is vault name or title
# Known vaults: bruno2brain-v3, loka2026
if [[ "$ARG1" == "bruno2brain-v3" ]] || [[ "$ARG1" == "loka2026" ]]; then
    VAULT_NAME="$ARG1"
    TITLE="$ARG2"
else
    TITLE="$ARG1"
fi

# Resolve vault path
if [[ -n "$VAULT_NAME" ]]; then
    # Explicit vault specified
    if [[ "$VAULT_NAME" == "bruno2brain-v3" ]]; then
        VAULT_DIR="$HOME/Bruno/vaults/bruno2brain-v3"
    elif [[ "$VAULT_NAME" == "loka2026" ]]; then
        VAULT_DIR="$HOME/loka/vaults/loka2026"
    else
        log_error "Unknown vault: $VAULT_NAME"
        echo "Available vaults: bruno2brain-v3, loka2026"
        exit 1
    fi
else
    # Detect from current directory (walks up tree to find vault root)
    VAULT_DIR=$("$VOICE_TOOLS/lib/detect-vault.sh" 2>/dev/null) || true

    if [[ -z "$VAULT_DIR" ]]; then
        # No vault found - use current directory (silent default)
        VAULT_DIR="$(pwd)"
        log_info "Not in a vault - saving to current directory"
    fi
fi

INBOX_DIR="$VAULT_DIR/inbox"

# Create inbox if it doesn't exist
if [[ ! -d "$INBOX_DIR" ]]; then
    mkdir -p "$INBOX_DIR"
    log_info "Created inbox directory: $INBOX_DIR"
fi

# Generate filename
if [[ -n "$TITLE" ]]; then
    SLUG=$(slugify "$TITLE")
    FILENAME="voice-${SLUG}.md"
else
    FILENAME="voice-$(get_timestamp).md"
fi

OUTPUT_FILE="$INBOX_DIR/$FILENAME"

# Check if file exists
if [[ -f "$OUTPUT_FILE" ]]; then
    log_error "File already exists: $FILENAME"
    exit 1
fi

log_info "Recording to $(basename "$VAULT_DIR")/inbox/$FILENAME"
echo ""

# Record using MCP voice tool via ToolSearch
# This ensures we use the proper vault-configured MCP server
echo "Recording will start shortly..."
echo "🎙️  Speak now... (automatic silence detection)"
```

After the bash script runs, use the ToolSearch and MCP voice tool:

1. Load the voice tools: `ToolSearch("select:record_voice_note")`
2. Call the tool with the title parameter
3. The tool will handle recording, transcription, and saving
4. Report success to the user with the file path
