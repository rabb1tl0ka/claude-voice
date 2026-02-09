# Voice Tools

Shared voice recording infrastructure for Bruno's vault system.

## Overview

This repo provides voice recording and transcription tools that work across multiple vaults:
- `bruno2brain-v3` (personal)
- `loka2026` (work)

## Architecture

```
voice-tools/
├── voice-to-inbox.sh       # One-shot voice note (manual stop)
├── listen.sh               # Background desktop audio recording
└── lib/
    ├── common.sh           # Shared functions
    ├── detect-vault.sh     # Find vault from cwd
    ├── detect-audio-sink.sh # Find active audio output
    └── transcribe.sh       # Whisper transcription
```

## Scripts

### voice-to-inbox.sh

One-shot voice note recording (microphone input).

**Usage:**
```bash
cd ~/Bruno/vaults/bruno2brain-v3
./voice-to-inbox.sh "my note title"
```

**Features:**
- Records from microphone (arecord)
- Press Enter to stop
- Transcribes with Whisper
- Saves to `inbox/voice-{title}.md`
- Vault-aware (uses script location)

### listen.sh

Background desktop audio recording (system output).

**Usage:**
```bash
# Start recording
listen.sh start <session-id> <vault-path>

# Stop recording
listen.sh stop <session-id>

# Check status
listen.sh status <session-id>

# List sessions
listen.sh list
```

**Features:**
- Records desktop audio output (speakers/headphones)
- Runs in background
- Multiple concurrent sessions
- Session metadata stored in `/tmp/claude-listen-sessions/`
- Audio stored in `/tmp/claude-listen-{session-id}.wav`

**Example:**
```bash
# Start recording
listen.sh start 20260208-143022 ~/Bruno/vaults/bruno2brain-v3

# Later... stop and get audio file
audio_file=$(listen.sh stop 20260208-143022)
echo "Audio saved to: $audio_file"
```

## Library Functions

### lib/detect-vault.sh

Finds vault directory by walking up from cwd, looking for:
- `.mcp.json`
- `CLAUDE.md`
- `.claude/` directory

**Usage:**
```bash
vault_dir=$(lib/detect-vault.sh)
echo "Current vault: $vault_dir"
```

### lib/detect-audio-sink.sh

Finds active audio output sink monitor for recording.

**Usage:**
```bash
monitor=$(lib/detect-audio-sink.sh)
echo "Recording from: $monitor"
```

**Supports:**
- PulseAudio (native)
- PipeWire (via pactl compatibility)

### lib/transcribe.sh

Transcribes audio using Whisper.

**Usage:**
```bash
transcript=$(lib/transcribe.sh /path/to/audio.wav base)
echo "$transcript"
```

**Arguments:**
- `audio-file`: Path to audio file
- `model`: Whisper model (default: base)

### lib/common.sh

Shared utility functions:
- `log_info()`, `log_success()`, `log_warn()`, `log_error()`
- `slugify()` - Convert text to filename-safe slug
- `get_timestamp()` - YYYYMMDD-HHMMSS format
- `notify()` - Desktop notifications

## Skills (Claude Code)

Voice tools are exposed via Claude Code skills:

| Skill | Command | Description |
|-------|---------|-------------|
| voice_note | `/voice_note [vault] [title]` | Record voice note to inbox |
| voice_prompt | `/voice_prompt` | Record voice and execute as prompt |
| listen_start | `/listen_start` | Start desktop audio recording |
| listen_stop | `/listen_stop` | Stop, transcribe, summarize |

See `.claude/skills/` in each vault for implementation details.

### Antifragile Vault Detection

Skills automatically detect vault context:

1. **Walks up from cwd** looking for vault indicators (`.mcp.json`, `CLAUDE.md`, `.claude/`)
2. **If vault found** → Uses `{vault-root}/inbox/`
3. **If not found** → Uses `{cwd}/inbox/` (creates if needed)
4. **Never prompts** - silent default always works

**Examples:**
- From `bruno2brain-v3/learning/foo/` → saves to `bruno2brain-v3/inbox/` ✅
- From `~/Downloads/` → creates and uses `~/Downloads/inbox/` ✅
- From anywhere in `loka2026/` → saves to `loka2026/inbox/` ✅

## Installation

### Per-Vault Setup

Each vault needs:

1. **MCP configuration** (`.mcp.json`):
   ```json
   {
     "mcpServers": {
       "voice": {
         "command": "/home/rabb1tl0ka/Bruno/code/MCP-voice/.venv/bin/python",
         "args": ["/home/rabb1tl0ka/Bruno/code/MCP-voice/server.py"],
         "env": {
           "VAULT_DIR": "/path/to/vault"
         }
       }
     }
   }
   ```

2. **Symlink voice-to-inbox.sh**:
   ```bash
   ln -s ~/Bruno/code/voice-tools/voice-to-inbox.sh ~/path/to/vault/
   ```

3. **Symlink skills**:
   ```bash
   mkdir -p ~/path/to/vault/.claude/skills
   cd ~/path/to/vault/.claude/skills
   ln -s ~/Bruno/vaults/bruno2brain-v3/.claude/skills/voice_*.md .
   ln -s ~/Bruno/vaults/bruno2brain-v3/.claude/skills/listen_*.md .
   ```

### Dependencies

- **Whisper**: `~/code/openai-whisper/.venv` (or set `WHISPER_VENV`)
- **PulseAudio/PipeWire**: `pactl`, `parecord` (via `pulseaudio-utils` or `pipewire-pulse`)
- **jq**: JSON parsing
- **ffprobe**: Audio duration detection (optional)
- **notify-send**: Desktop notifications (optional)

## Audio System

Currently configured for:
- **System**: PipeWire with PulseAudio compatibility
- **Recording tool**: `parecord` (PulseAudio)
- **Default sink**: Auto-detected via `pactl get-default-sink`
- **Monitor source**: `{sink-name}.monitor`

## Session Management

Desktop audio recording sessions are stored in `/tmp/claude-listen-sessions/`.

**Session file format** (`{session-id}.json`):
```json
{
  "session_id": "20260208-143022",
  "vault": "/home/rabb1tl0ka/Bruno/vaults/bruno2brain-v3",
  "start_time": "2026-02-08T14:30:22+00:00",
  "pid": 12345,
  "audio_file": "/tmp/claude-listen-20260208-143022.wav",
  "monitor_source": "bluez_output.28_FA_19_EA_E7_C1.1.monitor"
}
```

## Troubleshooting

### No audio recorded
- Check active sink: `pactl get-default-sink`
- Verify monitor source exists: `pactl list sources short`
- Test recording: `parecord --device={sink}.monitor test.wav`

### Transcription fails
- Verify Whisper installation: `~/code/openai-whisper/.venv/bin/whisper --help`
- Check audio file: `ffprobe /tmp/audio.wav`
- Test manually: `~/code/openai-whisper/.venv/bin/whisper test.wav --model base`

### Vault not detected
- Ensure vault has `.mcp.json`, `CLAUDE.md`, or `.claude/` directory
- Run from within vault directory
- Test: `lib/detect-vault.sh`

## Maintenance

### Cleanup temp files
```bash
# Remove old session files
rm -f /tmp/claude-listen-*.{wav,json,pid}
rm -rf /tmp/claude-listen-sessions/*.json

# Remove old Whisper temp files
rm -rf /tmp/tmp*/*.{txt,srt,vtt,json}
```

### Update Whisper model
```bash
export WHISPER_MODEL="medium"  # base, small, medium, large
lib/transcribe.sh audio.wav $WHISPER_MODEL
```

## Development

To add a new vault:

1. Create `.mcp.json` with voice server config
2. Symlink `voice-to-inbox.sh` to vault root
3. Symlink skills to `.claude/skills/`
4. Test: `cd /path/to/vault && /voice_note test`
