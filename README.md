# Claude Voice

Voice recording, transcription, and note-taking system for [Claude Code](https://claude.ai/claude-code).

An AI-first 2nd brain voice interface that enables:
- **Voice notes** - Speak thoughts directly into your vault inbox
- **Voice commands** - Speak prompts to Claude instead of typing
- **Desktop audio capture** - Record and transcribe meetings, videos, podcasts

## Architecture

This repo contains three tightly integrated modules:

```
claude-voice/
├── mcp-server/      # MCP server providing voice tools to Claude Code
├── voice-tools/     # Shared bash utilities for audio/transcription
└── skills/          # Claude Code skills (user-facing /commands)
```

## Features

### `/voice_note`
Record voice notes using automatic silence detection and save to vault inbox.

- Auto-detects silence (~1.5s pause stops recording)
- Transcribes with Whisper
- Saves to current or specified vault
- Custom titles or timestamp-based filenames

**Usage:**
```bash
/voice_note                              # Record to current vault
/voice_note "bitcoin thoughts"           # Custom title
/voice_note bruno2brain-v3 "daily log"  # Specific vault
```

### `/voice_prompt`
Speak commands to Claude instead of typing.

**Usage:**
```bash
/voice_prompt
[Speak: "Create a new note about quantum computing"]
[Claude executes your spoken command]
```

### `/listen_start` & `/listen_stop`
Record desktop audio output (speakers/headphones) for meeting notes, video summaries, etc.

**Usage:**
```bash
/listen_start    # Start background recording
[... attend meeting, watch video ...]
/listen_stop     # Stop, transcribe, summarize, save to inbox
```

## Installation

### Prerequisites

- Linux (Ubuntu/Debian recommended)
- Python 3.8+
- `jq` (`sudo apt install jq`)

Everything else (ffmpeg, portaudio, Whisper) is handled by the installer.

### One-shot install

```bash
git clone https://github.com/rabb1tpt/claude-voice.git
cd claude-voice
./install.sh
```

The installer will:
1. Check and offer to install system deps (`ffmpeg`, `portaudio19-dev`, `pulseaudio-utils`)
2. Install [Whisper](https://github.com/openai/whisper) for transcription (or detect an existing install)
3. Set up the MCP server Python venv
4. Symlink all skills to `~/.claude/skills/`
5. Register the `voice` MCP server in `~/.claude/settings.json` (available globally in all Claude Code sessions)

Then **restart Claude Code** and you're ready.

## Usage

Once installed, the skills are available in any Claude Code session:

```bash
/voice_note              # Quick voice capture
/voice_prompt            # Speak a command
/listen_start            # Start recording desktop audio
/listen_stop             # Stop and process recording
```

Or just ask naturally - Claude will invoke skills automatically when relevant:
- "Record a voice note about this meeting"
- "Listen to what I'm about to say and execute it"

## Audio Sources

- **Voice notes & prompts**: Microphone input (automatic silence detection)
- **Listen sessions**: Desktop audio output (speakers/headphones via PulseAudio loopback)

## Output Format

### Voice Notes
```markdown
# inbox/voice-{title}.md

[Transcription of your voice note]

#voice-note
```

### Listen Sessions
```markdown
# inbox/listen-YYYY-MM-DD-HHMMSS.md

## Summary
[AI-generated summary of the audio]

## Full Transcript
[Complete transcription with timestamps]

#listen-session
```

## How It Works

1. **Skills** (`.md` files in `skills/`) define the user interface - what commands are available and how to use them
2. **MCP Server** (`mcp-server/server.py`) provides the actual tools (`record_voice_note`, `listen`) to Claude Code via the Model Context Protocol
3. **Voice Tools** (`voice-tools/`) contain shared bash utilities for audio processing, transcription, and file handling

When you invoke a skill, Claude Code:
1. Loads the skill instructions
2. Calls the appropriate MCP tool
3. The MCP server uses voice-tools to record and transcribe
4. Returns the result to Claude for processing

## Troubleshooting

### "No MCP tools available"
- Check that `.mcp.json` exists in your vault and points to correct paths
- Verify Python venv is activated and dependencies installed
- Restart Claude Code session

### "Transcription failed"
- Verify Whisper is installed locally: `which whisper`
- Check audio file was created (temp files in `/tmp/`)
- Ensure ffmpeg is installed: `which ffmpeg`

### Desktop audio not recording
- Verify PulseAudio loopback is configured
- Check `pactl list sources` for monitor devices
- See voice-tools README for PulseAudio setup

## Philosophy: AI-First 2nd Brain

This system represents an **AI-first approach** to personal knowledge management:

**Traditional PKM**: Type → Organize → Search → Read
**AI-First PKM**: Speak → AI captures → Conversational retrieval

By removing friction at every step (voice vs. typing, AI organization vs. manual tagging, conversation vs. search), we enable:
- Capturing thoughts at the speed of speech
- Working on parallel projects as inspiration strikes
- Seamless context switching without breaking flow

The voice interface makes the 2nd brain feel like an extension of thought rather than a separate tool you have to "use."

## Contributing

Issues and PRs welcome! This is a personal workflow tool made public - if it helps you build your own AI-first systems, that's the goal.

## License

MIT License - see LICENSE file

## Credits

Built by [@rabb1tl0ka](https://github.com/rabb1tl0ka) as part of the bruno2brain-v3 vault system.

Powered by:
- [Claude Code](https://claude.ai/claude-code) - Anthropic's AI coding assistant
- [MCP](https://modelcontextprotocol.io/) - Model Context Protocol
- [Whisper](https://openai.com/research/whisper) - OpenAI's speech recognition
