#!/bin/bash
# Hook: Stop — gold completion flash, auto-fades to base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

"$SCRIPT_DIR/set-theme-state.sh" completed --session "$SESSION_ID"
exit 0
