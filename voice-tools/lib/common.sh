#!/usr/bin/env bash
#
# common.sh - Shared functions for voice tools
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC}  $*" >&2
}

log_success() {
    echo -e "${GREEN}✅${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $*" >&2
}

log_error() {
    echo -e "${RED}❌${NC} $*" >&2
}

# Slugify text for filenames
slugify() {
    local text="$1"
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get timestamp in YYYYMMDD-HHMMSS format
get_timestamp() {
    date +%Y%m%d-%H%M%S
}

# Get human-readable timestamp
get_timestamp_human() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Send desktop notification
notify() {
    local title="$1"
    local body="${2:-}"
    local timeout="${3:-2000}"

    if command_exists notify-send; then
        if [[ -n "$body" ]]; then
            notify-send "$title" "$body" -t "$timeout" 2>/dev/null || true
        else
            notify-send "$title" -t "$timeout" 2>/dev/null || true
        fi
    fi
}
