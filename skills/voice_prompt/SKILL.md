---
name: voice_prompt
description: Record a voice prompt and execute it
---

Record your voice, transcribe it, and execute the transcription as a prompt for Claude to process.

**Usage:**
- `/voice_prompt` - Record and execute

**Example flow:**
1. You say: "Create a new note about quantum computing basics"
2. Claude transcribes: "Create a new note about quantum computing basics"
3. Claude executes: Creates the note as requested

---

## Implementation

This skill uses the MCP "listen" tool:

1. Load the voice tool: `ToolSearch("select:listen")`
2. Call `mcp__voice__listen` (or the appropriate tool name)
3. The tool returns transcription in format: `[Voice input from user]: <transcription>`
4. Execute the transcription as if the user typed it

The MCP tool handles:
- Recording with automatic silence detection
- Transcription with Whisper
- Returning the text for processing

Claude should then process the transcribed text as a normal user request.
