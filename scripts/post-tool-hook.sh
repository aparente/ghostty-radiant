#!/bin/bash
# Hook: PostToolUse — shift to working state
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Check for errors in tool result
WAS_ERROR=$(echo "$INPUT" | jq -r '.tool_error // empty')
if [[ -n "$WAS_ERROR" ]]; then
  "$SCRIPT_DIR/set-theme-state.sh" error --session "$SESSION_ID"
else
  "$SCRIPT_DIR/set-theme-state.sh" working --session "$SESSION_ID"
fi
exit 0
