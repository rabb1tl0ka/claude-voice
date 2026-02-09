#!/usr/bin/env bash
#
# detect-vault.sh - Find vault directory from current working directory
#
# Walks up the directory tree looking for vault indicators:
#   - .mcp.json
#   - CLAUDE.md
#   - .claude/ directory
#
# Usage:
#   detect-vault.sh
#
# Returns:
#   Vault root path (absolute) on stdout
#   Exit code 0 on success, 1 on failure
#

set -e

# Start from current directory
current_dir="$(pwd)"

# Walk up the directory tree
while [[ "$current_dir" != "/" ]]; do
    # Check for vault indicators
    if [[ -f "$current_dir/.mcp.json" ]] || \
       [[ -f "$current_dir/CLAUDE.md" ]] || \
       [[ -d "$current_dir/.claude" ]]; then
        echo "$current_dir"
        exit 0
    fi

    # Move up one directory
    current_dir="$(dirname "$current_dir")"
done

# Not found
exit 1
