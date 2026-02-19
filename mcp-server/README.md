# MCP-voice

An MCP server for voice input - record voice notes or speak commands for Claude to process.

## Setup

Use the installer in the repo root — it handles everything automatically:

```bash
./install.sh
```

### Manual setup (advanced)

```bash
cd mcp-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Then add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "voice": {
      "command": "/path/to/claude-voice/mcp-server/.venv/bin/python",
      "args": ["/path/to/claude-voice/mcp-server/server.py"],
      "env": {
        "WHISPER_VENV": "/path/to/openai-whisper/.venv"
      }
    }
  }
}
```

Restart Claude Code — the voice tools will be available.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VAULT_DIR` | Path to the vault (must have an `inbox/` directory) | `.` (current directory) |
| `WHISPER_VENV` | Path to Whisper virtual environment | `~/code/openai-whisper/.venv` |
| `WHISPER_MODEL` | Whisper model to use | `base` |

## Tools

| Tool | Description |
|------|-------------|
| `record_voice_note` | Record, transcribe, and save to vault inbox |
| `listen` | Record, transcribe, and return as input for Claude to process |

## Usage

In Claude Code:
- "record Bitcoin thoughts" - saves transcription to inbox
- "listen" - speak your request, Claude processes it

## Dependencies

- `arecord` (ALSA) for audio recording
- Whisper for transcription (configured via `WHISPER_VENV`)
