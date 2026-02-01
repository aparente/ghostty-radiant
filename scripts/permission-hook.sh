#!/bin/bash
# Hook: PermissionRequest — warm amber tint indicating user attention needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

"$SCRIPT_DIR/set-theme-state.sh" needs_input --session "$SESSION_ID"
exit 0
