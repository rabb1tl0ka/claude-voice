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

python3 --version >/dev/null 2>&1 || error "Python 3 is required. Install it with: brew install python"
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
    ok "Homebrew found: $(brew --prefix)"
fi

# ── 3. System dependencies ────────────────────────────────────────────────────
header "3. System dependencies"

MISSING=()
command -v ffmpeg >/dev/null 2>&1   || MISSING+=("ffmpeg")
command -v jq >/dev/null 2>&1       || MISSING+=("jq")

# portaudio needed for pyaudio
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
        warn "Skipped — transcription won't work until Whisper is installed"
        warn "Set WHISPER_VENV in ~/.claude/settings.json when ready"
        WHISPER_VENV="$DEFAULT_WHISPER_VENV"
    fi
fi

# ── 5. MCP server Python venv ─────────────────────────────────────────────────
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

# ── 6. Skills ─────────────────────────────────────────────────────────────────
header "6. Claude Code skills"

mkdir -p "$SKILLS_DIR"

# listen_start / listen_stop use PulseAudio — Linux only
for skill in voice_prompt voice_note; do
    src="$REPO_DIR/skills/$skill"
    dst="$SKILLS_DIR/$skill"

    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
        rm -rf "$dst"
    fi

    ln -s "$src" "$dst"
    ok "Linked: $skill → $dst"
done

warn "listen_start / listen_stop require PulseAudio — skipped on macOS"

# ── 7. Global MCP config in ~/.claude/settings.json ──────────────────────────
header "7. Claude Code MCP config"

PYTHON_BIN="$MCP_SERVER/.venv/bin/python"
SERVER_PY="$MCP_SERVER/server.py"

NEW_ENTRY=$(jq -n \
    --arg cmd "$PYTHON_BIN" \
    --argjson args "[\"$SERVER_PY\"]" \
    --arg whisper_venv "$WHISPER_VENV" \
    '{command: $cmd, args: $args, env: {WHISPER_VENV: $whisper_venv}}')

if [[ -f "$SETTINGS_FILE" ]]; then
    UPDATED=$(jq --argjson entry "$NEW_ENTRY" '.mcpServers.voice = $entry' "$SETTINGS_FILE")
    echo "$UPDATED" > "$SETTINGS_FILE"
else
    mkdir -p "$CLAUDE_DIR"
    echo '{}' | jq --argjson entry "$NEW_ENTRY" '.mcpServers.voice = $entry' > "$SETTINGS_FILE"
fi

ok "Added 'voice' server to $SETTINGS_FILE"

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
