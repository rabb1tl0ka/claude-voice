#!/usr/bin/env bash
#
# detect-audio-sink.sh - Find active audio output sink monitor for recording
#
# Works with PulseAudio (native) or PipeWire (pactl compatibility)
#
# Usage:
#   detect-audio-sink.sh
#
# Returns:
#   Monitor source name on stdout (e.g., "bluez_output.XXX.monitor")
#   Exit code 0 on success, 1 on failure
#

set -e

# Check if pactl is available
if ! command -v pactl >/dev/null 2>&1; then
    echo "Error: pactl not found. Install pulseaudio-utils or pipewire-pulse." >&2
    exit 1
fi

# Get default sink name
default_sink=$(pactl get-default-sink 2>/dev/null)

if [[ -z "$default_sink" ]]; then
    echo "Error: Could not detect default audio sink." >&2
    exit 1
fi

# Monitor source is typically the sink name with .monitor appended
monitor_source="${default_sink}.monitor"

# Verify the monitor source exists
if pactl list sources short | grep -q "^[0-9]*[[:space:]]*${monitor_source}"; then
    echo "$monitor_source"
    exit 0
else
    echo "Error: Monitor source not found: $monitor_source" >&2
    exit 1
fi
