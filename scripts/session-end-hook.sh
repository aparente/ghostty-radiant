#!/bin/bash
# Hook: SessionEnd — restore original terminal colors
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

"$SCRIPT_DIR/set-theme-state.sh" restore --session "$SESSION_ID"

# Clean up session TTY file
rm -f "/tmp/radiant-tty-${SESSION_ID}"
exit 0
