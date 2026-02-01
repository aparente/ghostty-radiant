#!/bin/bash
# Hook: SessionStart — capture TTY path, flash green, settle to base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Capture this session's TTY for later hooks (which may run in subshells)
TTY_PATH=$(tty 2>/dev/null || echo "")
if [[ -n "$SESSION_ID" ]] && [[ -n "$TTY_PATH" ]] && [[ "$TTY_PATH" != "not a tty" ]]; then
  echo "$TTY_PATH" > "/tmp/radiant-tty-${SESSION_ID}"
fi

"$SCRIPT_DIR/set-theme-state.sh" connected --tty "$TTY_PATH" --session "$SESSION_ID"
exit 0
