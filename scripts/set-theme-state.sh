#!/bin/bash
# ghostty-radiant: Set terminal theme state via OSC sequences
# Usage: set-theme-state.sh <state_name> [--tty <path>] [--session <id>]
#
# Targets a specific Ghostty tab by writing OSC sequences to its TTY.
# Each Claude Code session has its own TTY, so only that tab recolors.

STATE_NAME="${1:-base}"
TTY_PATH=""
SESSION_ID=""
CONFIG_FILE="${GHOSTTY_RADIANT_CONFIG:-${HOME}/.claude/radiant-theme.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --tty)
      TTY_PATH="$2"
      shift 2
      ;;
    --session)
      SESSION_ID="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Resolve TTY: explicit arg > own tty > stored in session file
resolve_tty() {
  if [[ -n "$TTY_PATH" ]] && [[ -w "$TTY_PATH" ]]; then
    echo "$TTY_PATH"
    return
  fi

  # Try our own tty
  local my_tty
  my_tty=$(tty 2>/dev/null)
  if [[ -n "$my_tty" ]] && [[ "$my_tty" != "not a tty" ]] && [[ -w "$my_tty" ]]; then
    echo "$my_tty"
    return
  fi

  # Try session-stored TTY from cast's SQLite DB
  if [[ -n "$SESSION_ID" ]]; then
    local cast_db="${HOME}/.cast/cast.db"
    if [[ -f "$cast_db" ]]; then
      local stored_tty
      stored_tty=$(sqlite3 "$cast_db" "SELECT tty_path FROM sessions WHERE session_id='$SESSION_ID' LIMIT 1" 2>/dev/null)
      if [[ -n "$stored_tty" ]] && [[ -w "$stored_tty" ]]; then
        echo "$stored_tty"
        return
      fi
    fi
  fi

  # Try session file (written by our own SessionStart hook)
  if [[ -n "$SESSION_ID" ]] && [[ -f "/tmp/radiant-tty-${SESSION_ID}" ]]; then
    local file_tty
    file_tty=$(cat "/tmp/radiant-tty-${SESSION_ID}" 2>/dev/null)
    if [[ -n "$file_tty" ]] && [[ -w "$file_tty" ]]; then
      echo "$file_tty"
      return
    fi
  fi

  echo ""
}

TARGET_TTY=$(resolve_tty)

if [[ -z "$TARGET_TTY" ]]; then
  # No writable TTY — silently exit (hook might be in a subshell)
  exit 0
fi

# Check config
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config not found: $CONFIG_FILE" >&2
  exit 1
fi

# Stop any running animation for this TTY
ANIM_PID_FILE="/tmp/radiant-anim-$(echo "$TARGET_TTY" | tr '/' '_').pid"
stop_animation() {
  if [[ -f "$ANIM_PID_FILE" ]]; then
    local pid
    pid=$(cat "$ANIM_PID_FILE" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    fi
    rm -f "$ANIM_PID_FILE"
  fi
}

stop_animation

# Handle restore — reset to original colors
if [[ "$STATE_NAME" == "restore" ]]; then
  # OSC 110 = reset foreground, 111 = reset background, 112 = reset cursor
  printf '\033]110\033\\' > "$TARGET_TTY"
  printf '\033]111\033\\' > "$TARGET_TTY"
  printf '\033]112\033\\' > "$TARGET_TTY"
  rm -f "/tmp/radiant-state-$(echo "$TARGET_TTY" | tr '/' '_').txt"
  exit 0
fi

# Read state from config
BG=$(jq -r ".states.${STATE_NAME}.bg // empty" "$CONFIG_FILE")
FG=$(jq -r ".states.${STATE_NAME}.fg // empty" "$CONFIG_FILE")
CURSOR=$(jq -r ".states.${STATE_NAME}.cursor // empty" "$CONFIG_FILE")
TRANSITION=$(jq -r ".states.${STATE_NAME}.transition // \"instant\"" "$CONFIG_FILE")

if [[ -z "$BG" ]]; then
  echo "Unknown state: $STATE_NAME" >&2
  exit 1
fi

# Emit OSC sequences to the target TTY
emit_colors() {
  local bg="$1" fg="$2" cursor="$3" tty="$4"
  [[ -n "$bg" ]]     && printf '\033]11;%s\033\\' "$bg" > "$tty"
  [[ -n "$fg" ]]     && printf '\033]10;%s\033\\' "$fg" > "$tty"
  [[ -n "$cursor" ]] && printf '\033]12;%s\033\\' "$cursor" > "$tty"
}

if [[ "$TRANSITION" == "animate" ]]; then
  # Delegate to animation script
  END_BG=$(jq -r ".states.${STATE_NAME}.animation.end_bg // \"$BG\"" "$CONFIG_FILE")
  STEPS=$(jq -r ".states.${STATE_NAME}.animation.steps // 8" "$CONFIG_FILE")
  STEP_MS=$(jq -r ".states.${STATE_NAME}.animation.step_ms // 120" "$CONFIG_FILE")

  "$SCRIPT_DIR/animate-transition.sh" "$TARGET_TTY" "$BG" "$END_BG" "$CURSOR" "$STEPS" "$STEP_MS" &
  echo $! > "$ANIM_PID_FILE"
else
  emit_colors "$BG" "$FG" "$CURSOR" "$TARGET_TTY"
fi

# Record current state
STATE_FILE="/tmp/radiant-state-$(echo "$TARGET_TTY" | tr '/' '_').txt"
echo "$STATE_NAME" > "$STATE_FILE"

# Handle auto-transitions (e.g., connected -> base after 1.5s)
AUTO_TO=$(jq -r ".states.${STATE_NAME}.auto_transition.to // empty" "$CONFIG_FILE")
AUTO_MS=$(jq -r ".states.${STATE_NAME}.auto_transition.after_ms // 0" "$CONFIG_FILE")

if [[ -n "$AUTO_TO" ]] && [[ "$AUTO_MS" -gt 0 ]]; then
  AUTO_SEC=$(echo "scale=3; $AUTO_MS / 1000" | bc)
  (
    sleep "$AUTO_SEC"
    # Only transition if still in expected state
    if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "$STATE_NAME" ]]; then
      "$0" "$AUTO_TO" --tty "$TARGET_TTY"
    fi
  ) &
fi

exit 0
