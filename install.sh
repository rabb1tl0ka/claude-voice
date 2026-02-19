#!/usr/bin/env bash
#
# install.sh - One-shot setup for claude-voice
#
# Sets up the MCP server, installs skills, and configures Claude Code globally.
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
echo -e "${BOLD}Claude Voice — Installer${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. OS check ───────────────────────────────────────────────────────────────
header "1. System check"

if [[ "$(uname)" != "Linux" ]]; then
    error "This installer currently supports Linux only."
fi

python3 --version >/dev/null 2>&1 || error "Python 3 is required. Install it first."
ok "Python: $(python3 --version)"

if ! command -v jq >/dev/null 2>&1; then
    error "jq is required. Install with: sudo apt install jq"
fi
ok "jq found"

# ── 2. System dependencies ────────────────────────────────────────────────────
header "2. System dependencies"

MISSING=()
command -v ffmpeg >/dev/null 2>&1 || MISSING+=("ffmpeg")

# portaudio headers needed for pyaudio compilation
if ! python3 -c "import pyaudio" 2>/dev/null; then
    dpkg -s portaudio19-dev >/dev/null 2>&1 || MISSING+=("portaudio19-dev")
fi

# parecord optional (desktop audio capture / listen_start)
command -v parecord >/dev/null 2>&1 || MISSING+=("pulseaudio-utils")

if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing packages: ${MISSING[*]}"
    read -p "  Install now with apt? [Y/n] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo apt install -y "${MISSING[@]}"
        ok "Dependencies installed"
    else
        warn "Skipped — some features may not work without these"
    fi
else
    ok "All system deps present"
fi

# ── 3. Whisper ────────────────────────────────────────────────────────────────
header "3. Whisper (speech-to-text)"

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
        warn "Set WHISPER_VENV in your .mcp.json when ready"
        WHISPER_VENV="$DEFAULT_WHISPER_VENV"
    fi
fi

# ── 4. MCP server Python venv ─────────────────────────────────────────────────
header "4. MCP server"

info "Creating Python venv..."
python3 -m venv "$MCP_SERVER/.venv"

info "Installing dependencies..."
"$MCP_SERVER/.venv/bin/pip" install -q -r "$MCP_SERVER/requirements.txt"

ok "MCP server ready at $MCP_SERVER/.venv"

# ── 5. Skills ─────────────────────────────────────────────────────────────────
header "5. Claude Code skills"

mkdir -p "$SKILLS_DIR"

for skill in voice_prompt voice_note listen_start listen_stop; do
    src="$REPO_DIR/skills/$skill"
    dst="$SKILLS_DIR/$skill"

    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
        rm -rf "$dst"
    fi

    ln -s "$src" "$dst"
    ok "Linked: $skill → $dst"
done

# ── 6. Global MCP config in ~/.claude/settings.json ──────────────────────────
header "6. Claude Code MCP config"

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
echo "    /listen_start    — start recording desktop audio"
echo "    /listen_stop     — stop and transcribe"
echo ""
