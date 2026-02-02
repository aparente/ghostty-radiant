#!/bin/bash
# ghostty-aura: SessionEnd hook — restore original terminal colors, clean up
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

"$SCRIPT_DIR/set-theme-state.sh" restore --session "$SESSION_ID"

# Resolve TTY for cleanup of per-TTY temp files
TTY_PATH=""
if [[ -n "$SESSION_ID" ]] && [[ -f "/tmp/aura-tty-${SESSION_ID}" ]]; then
  TTY_PATH=$(cat "/tmp/aura-tty-${SESSION_ID}" 2>/dev/null)
fi

if [[ -n "$TTY_PATH" ]]; then
  TTY_SLUG=$(echo "$TTY_PATH" | tr '/' '_')

  # Kill any running animation process
  ANIM_PID_FILE="/tmp/aura-anim-${TTY_SLUG}.pid"
  if [[ -f "$ANIM_PID_FILE" ]]; then
    pid=$(cat "$ANIM_PID_FILE" 2>/dev/null)
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    rm -f "$ANIM_PID_FILE"
  fi

  # Kill any running auto-transition process
  AUTO_PID_FILE="/tmp/aura-auto-${TTY_SLUG}.pid"
  if [[ -f "$AUTO_PID_FILE" ]]; then
    pid=$(cat "$AUTO_PID_FILE" 2>/dev/null)
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    rm -f "$AUTO_PID_FILE"
  fi

  # Remove state file
  rm -f "/tmp/aura-state-${TTY_SLUG}.txt"
fi

# Clean up session files
rm -f "/tmp/aura-tty-${SESSION_ID}"
rm -f "/tmp/aura-base-${SESSION_ID}.json"
exit 0
