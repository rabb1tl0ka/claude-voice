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

- Python 3.8+
- ffmpeg (for audio processing)
- OpenAI API key (for Whisper transcription)
- PulseAudio (Linux) for desktop audio capture

### 1. Clone the repo

```bash
cd ~/loka/code  # or wherever you keep your code
git clone git@github.com:rabb1tl0ka/claude-voice.git
cd claude-voice
```

### 2. Set up Python environment

```bash
cd mcp-server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure OpenAI API key

Add to your shell profile (~/.bashrc or ~/.zshrc):

```bash
export OPENAI_API_KEY="your-api-key-here"
```

### 4. Install skills globally

Symlink skills to make them available in all Claude Code sessions:

```bash
cd ~/.claude/skills
ln -s ~/loka/code/claude-voice/skills/voice_note
ln -s ~/loka/code/claude-voice/skills/voice_prompt
ln -s ~/loka/code/claude-voice/skills/listen_start
ln -s ~/loka/code/claude-voice/skills/listen_stop
```

### 5. Configure vault(s)

For each vault where you want voice features, create `.mcp.json`:

```json
{
  "mcpServers": {
    "voice": {
      "command": "/home/yourusername/loka/code/claude-voice/mcp-server/.venv/bin/python",
      "args": ["/home/yourusername/loka/code/claude-voice/mcp-server/server.py"],
      "env": {
        "VAULT_DIR": "/home/yourusername/path/to/your/vault"
      }
    }
  }
}
```

See `.mcp.json.example` for a template.

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
- Verify OPENAI_API_KEY is set: `echo $OPENAI_API_KEY`
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
