#!/usr/bin/env bash
#
# install-macos.sh - One-shot setup for claude-voice on macOS
#
# Sets up the MCP server, installs skills, and configures Claude Code globally.
#
# Note: listen_start / listen_stop require PulseAudio and are Linux-only.
# On macOS, voice_prompt and voice_note are fully supported.
#

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
MCP_SERVER="$REPO_DIR/mcp-server"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "  ${GREEN}→${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
error() { echo -e "\n  ${RED}✗ Error:${NC} $1\n" >&2; exit 1; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
header() { echo -e "\n${BOLD}$1${NC}"; }

echo ""
echo -e "${BOLD}Claude Voice — Installer (macOS)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. System check ───────────────────────────────────────────────────────────
header "1. System check"

[[ "$(uname)" == "Darwin" ]] || error "This script is for macOS. On Linux, run ./install.sh instead."

python3 --version >/dev/null 2>&1 || error "Python 3 is required. Install with: brew install python"
ok "Python: $(python3 --version)"

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
header "2. Homebrew"

if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found"
    echo "  Homebrew is needed to install dependencies."
    read -p "  Install Homebrew now? [Y/n] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        ok "Homebrew installed"
    else
        error "Homebrew is required. Install it from https://brew.sh and re-run."
    fi
else
    ok "Homebrew: $(brew --prefix)"
fi

# ── 3. System dependencies ────────────────────────────────────────────────────
header "3. System dependencies"

MISSING=()
command -v jq     >/dev/null 2>&1 || MISSING+=("jq")
command -v ffmpeg >/dev/null 2>&1 || MISSING+=("ffmpeg")

# portaudio needed to compile pyaudio
if ! python3 -c "import pyaudio" 2>/dev/null; then
    brew list portaudio >/dev/null 2>&1 || MISSING+=("portaudio")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing packages: ${MISSING[*]}"
    read -p "  Install now with brew? [Y/n] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        brew install "${MISSING[@]}"
        ok "Dependencies installed"
    else
        warn "Skipped — some features may not work without these"
    fi
else
    ok "All system deps present"
fi

# ── 4. Whisper ────────────────────────────────────────────────────────────────
header "4. Whisper (speech-to-text)"

DEFAULT_WHISPER_VENV="$HOME/code/openai-whisper/.venv"
WHISPER_VENV=""

if [[ -x "$DEFAULT_WHISPER_VENV/bin/whisper" ]]; then
    WHISPER_VENV="$DEFAULT_WHISPER_VENV"
    ok "Found at $WHISPER_VENV"
elif command -v whisper >/dev/null 2>&1; then
    WHISPER_BIN="$(command -v whisper)"
    WHISPER_VENV="$(dirname "$(dirname "$WHISPER_BIN")")"
    ok "Found in PATH: $WHISPER_VENV"
else
    warn "Whisper not found"
    echo "  Will install to: $DEFAULT_WHISPER_VENV"
    echo "  The 'base' model (~140MB) downloads on first use."
    echo ""
    read -p "  Install Whisper now? [Y/n] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        mkdir -p "$(dirname "$DEFAULT_WHISPER_VENV")"
        python3 -m venv "$DEFAULT_WHISPER_VENV"
        "$DEFAULT_WHISPER_VENV/bin/pip" install -q openai-whisper
        WHISPER_VENV="$DEFAULT_WHISPER_VENV"
        ok "Whisper installed at $WHISPER_VENV"
    else
        warn "Skipped — set WHISPER_VENV in ~/.claude/settings.json when ready"
        WHISPER_VENV="$DEFAULT_WHISPER_VENV"
    fi
fi

# ── 5. MCP server venv ────────────────────────────────────────────────────────
header "5. MCP server"

info "Creating Python venv..."
python3 -m venv "$MCP_SERVER/.venv"

info "Installing dependencies..."
# On macOS, pyaudio needs portaudio headers from brew
PORTAUDIO_PREFIX="$(brew --prefix portaudio 2>/dev/null || echo "")"
if [[ -n "$PORTAUDIO_PREFIX" ]]; then
    CFLAGS="-I$PORTAUDIO_PREFIX/include" \
    LDFLAGS="-L$PORTAUDIO_PREFIX/lib" \
    "$MCP_SERVER/.venv/bin/pip" install -q -r "$MCP_SERVER/requirements.txt"
else
    "$MCP_SERVER/.venv/bin/pip" install -q -r "$MCP_SERVER/requirements.txt"
fi

ok "MCP server ready at $MCP_SERVER/.venv"

# ── 6. Vault for voice_note (optional) ───────────────────────────────────────
header "6. Vault for voice_note (optional)"

VAULT_DIR=""
echo "  /voice_note saves transcriptions to a vault's inbox/ folder."
echo "  Skip this if you only want /voice_prompt."
echo ""
read -p "  Configure a vault now? [y/N] " -n 1 -r; echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "  Vault path (e.g. ~/notes): " VAULT_INPUT
    VAULT_DIR="${VAULT_INPUT/#\~/$HOME}"

    if [[ ! -d "$VAULT_DIR" ]]; then
        read -p "  Directory not found. Create it? [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            mkdir -p "$VAULT_DIR/inbox"
            ok "Created $VAULT_DIR/inbox"
        else
            warn "Skipped — configure VAULT_DIR in ~/.claude/settings.json manually"
            VAULT_DIR=""
        fi
    elif [[ ! -d "$VAULT_DIR/inbox" ]]; then
        read -p "  No inbox/ found. Create $VAULT_DIR/inbox? [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            mkdir -p "$VAULT_DIR/inbox"
            ok "Created inbox/"
        else
            warn "/voice_note needs an inbox/ folder — create it manually"
        fi
    else
        ok "Vault: $VAULT_DIR"
    fi
else
    info "Skipped — add VAULT_DIR to ~/.claude/settings.json later if needed"
fi

# ── 7. Skills ─────────────────────────────────────────────────────────────────
header "7. Claude Code skills"

mkdir -p "$SKILLS_DIR"

# listen_start / listen_stop use PulseAudio — Linux only
for skill in voice_prompt voice_note; do
    src="$REPO_DIR/skills/$skill"
    dst="$SKILLS_DIR/$skill"

    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
        rm -rf "$dst"
    fi

    ln -s "$src" "$dst"
    ok "Linked: $skill"
done

warn "listen_start / listen_stop require PulseAudio — skipped on macOS"

# ── 8. Claude Code MCP config ─────────────────────────────────────────────────
header "8. Claude Code MCP config"

PYTHON_BIN="$MCP_SERVER/.venv/bin/python"
SERVER_PY="$MCP_SERVER/server.py"

mkdir -p "$CLAUDE_DIR"

if command -v jq >/dev/null 2>&1; then
    if [[ -n "$VAULT_DIR" ]]; then
        NEW_ENTRY=$(jq -n \
            --arg cmd "$PYTHON_BIN" \
            --argjson args "[\"$SERVER_PY\"]" \
            --arg whisper_venv "$WHISPER_VENV" \
            --arg vault_dir "$VAULT_DIR" \
            '{command: $cmd, args: $args, env: {WHISPER_VENV: $whisper_venv, VAULT_DIR: $vault_dir}}')
    else
        NEW_ENTRY=$(jq -n \
            --arg cmd "$PYTHON_BIN" \
            --argjson args "[\"$SERVER_PY\"]" \
            --arg whisper_venv "$WHISPER_VENV" \
            '{command: $cmd, args: $args, env: {WHISPER_VENV: $whisper_venv}}')
    fi

    if [[ -f "$SETTINGS_FILE" ]]; then
        UPDATED=$(jq --argjson entry "$NEW_ENTRY" '.mcpServers.voice = $entry' "$SETTINGS_FILE")
        echo "$UPDATED" > "$SETTINGS_FILE"
    else
        echo '{}' | jq --argjson entry "$NEW_ENTRY" '.mcpServers.voice = $entry' > "$SETTINGS_FILE"
    fi

    ok "Added 'voice' server to $SETTINGS_FILE"
else
    warn "jq not available — add the following to ~/.claude/settings.json manually:"
    echo ""
    echo '    "mcpServers": {'
    echo '      "voice": {'
    echo "        \"command\": \"$PYTHON_BIN\","
    echo "        \"args\": [\"$SERVER_PY\"],"
    echo "        \"env\": {"
    echo "          \"WHISPER_VENV\": \"$WHISPER_VENV\""
    [[ -n "$VAULT_DIR" ]] && echo "          \"VAULT_DIR\": \"$VAULT_DIR\""
    echo "        }"
    echo "      }"
    echo "    }"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}${BOLD}✅ All done! Restart Claude Code.${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Then try:"
echo ""
echo "    /voice_prompt    — speak a command to Claude"
echo "    /voice_note      — dictate a voice note"
echo ""
echo "  Note: /listen_start and /listen_stop are Linux-only."
echo ""
echo -e "  ${YELLOW}⚠${NC}  macOS microphone access: on first use, macOS will ask you to"
echo "     grant microphone permission to your terminal app. Allow it."
echo ""
