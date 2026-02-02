#!/bin/bash
# ghostty-aura: PermissionRequest hook — amber tint for user attention
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

"$SCRIPT_DIR/set-theme-state.sh" needs_input --session "$SESSION_ID" || echo "ghostty-aura [permission]: failed to set needs_input state" >&2
exit 0
