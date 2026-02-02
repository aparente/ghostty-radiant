#!/bin/bash
# ghostty-aura: Set terminal theme state via OSC sequences
# Usage: set-theme-state.sh <state_name> [--tty <path>] [--session <id>]
#
# Reads base colors queried at session start, blends with configured tint
# using Node.js color math, and writes OSC sequences to the session TTY.

STATE_NAME="${1:-base}"
TTY_PATH=""
SESSION_ID=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

log_err() { echo "ghostty-aura [set-theme-state]: $*" >&2; }

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --tty)     TTY_PATH="$2";    shift 2 ;;
    --session) SESSION_ID="$2";  shift 2 ;;
    *)         shift ;;
  esac
done

# --- Resolve TTY ---
resolve_tty() {
  if [[ -n "$TTY_PATH" ]] && [[ -w "$TTY_PATH" ]]; then
    echo "$TTY_PATH"; return
  fi
  local my_tty
  my_tty=$(tty 2>/dev/null)
  if [[ -n "$my_tty" ]] && [[ "$my_tty" != "not a tty" ]] && [[ -w "$my_tty" ]]; then
    echo "$my_tty"; return
  fi
  if [[ -n "$SESSION_ID" ]] && [[ -f "/tmp/aura-tty-${SESSION_ID}" ]]; then
    local file_tty
    file_tty=$(cat "/tmp/aura-tty-${SESSION_ID}" 2>/dev/null)
    if [[ -n "$file_tty" ]] && [[ -w "$file_tty" ]]; then
      echo "$file_tty"; return
    fi
  fi
  echo ""
}

TARGET_TTY=$(resolve_tty)
[[ -z "$TARGET_TTY" ]] && exit 0

# --- Stop any running animation/auto-transition for this TTY ---
TTY_SLUG=$(echo "$TARGET_TTY" | tr '/' '_')
ANIM_PID_FILE="/tmp/aura-anim-${TTY_SLUG}.pid"
if [[ -f "$ANIM_PID_FILE" ]]; then
  pid=$(cat "$ANIM_PID_FILE" 2>/dev/null)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  fi
  rm -f "$ANIM_PID_FILE"
fi
AUTO_PID_FILE="/tmp/aura-auto-${TTY_SLUG}.pid"
if [[ -f "$AUTO_PID_FILE" ]]; then
  pid=$(cat "$AUTO_PID_FILE" 2>/dev/null)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
  fi
  rm -f "$AUTO_PID_FILE"
fi

# --- Restore / base: reset to original queried colors ---
if [[ "$STATE_NAME" == "restore" ]] || [[ "$STATE_NAME" == "base" ]]; then
  BASE_FILE="/tmp/aura-base-${SESSION_ID}.json"
  if [[ -f "$BASE_FILE" ]]; then
    BG=$(jq -r '.bg // empty' "$BASE_FILE")
    FG=$(jq -r '.fg // empty' "$BASE_FILE")
    CURSOR=$(jq -r '.cursor // empty' "$BASE_FILE")
    [[ -n "$BG" ]]     && printf '\033]11;%s\033\\' "$BG" > "$TARGET_TTY"
    [[ -n "$FG" ]]     && printf '\033]10;%s\033\\' "$FG" > "$TARGET_TTY"
    [[ -n "$CURSOR" ]] && printf '\033]12;%s\033\\' "$CURSOR" > "$TARGET_TTY"
  else
    # No base file — use OSC reset codes
    printf '\033]110\033\\' > "$TARGET_TTY"
    printf '\033]111\033\\' > "$TARGET_TTY"
    printf '\033]112\033\\' > "$TARGET_TTY"
  fi
  rm -f "/tmp/aura-state-$(echo "$TARGET_TTY" | tr '/' '_').txt"
  exit 0
fi

# --- Load base colors ---
BASE_FILE="/tmp/aura-base-${SESSION_ID}.json"
if [[ ! -f "$BASE_FILE" ]]; then
  exit 0  # No base colors queried yet
fi
BASE_BG=$(jq -r '.bg // empty' "$BASE_FILE")
BASE_FG=$(jq -r '.fg // empty' "$BASE_FILE")
BASE_CURSOR=$(jq -r '.cursor // empty' "$BASE_FILE")
[[ -z "$BASE_BG" ]] && exit 0

# --- Load state config from Node helper ---
STATE_JSON=$(node "$LIB_DIR/config.js" get-state "$STATE_NAME" 2>/dev/null)
if [[ -z "$STATE_JSON" ]]; then
  log_err "failed to load state config for '$STATE_NAME'"
  exit 1
fi

TINT=$(echo "$STATE_JSON" | jq -r '.tint')
INTENSITY=$(echo "$STATE_JSON" | jq -r '.intensity')
TRANSITION=$(echo "$STATE_JSON" | jq -r '.transition // "instant"')
AUTO_TO=$(echo "$STATE_JSON" | jq -r '.auto_to // empty')
AUTO_MS=$(echo "$STATE_JSON" | jq -r '.auto_ms // 0')

# --- Compute blended colors via Node ---
BLENDED_BG=$(node "$LIB_DIR/color.js" blend "$BASE_BG" "$TINT" "$INTENSITY" 2>/dev/null)
CURSOR_INTENSITY=$(node -e "console.log(parseFloat(process.argv[1]) * 0.5)" -- "$INTENSITY" 2>/dev/null)
BLENDED_CURSOR=$(node "$LIB_DIR/color.js" blend "$BASE_CURSOR" "$TINT" "$CURSOR_INTENSITY" 2>/dev/null)

if [[ -z "$BLENDED_BG" ]] || [[ -z "$BLENDED_CURSOR" ]]; then
  log_err "color blend failed for state '$STATE_NAME' (bg='$BLENDED_BG' cursor='$BLENDED_CURSOR')"
  exit 1
fi

# --- Apply ---
if [[ "$TRANSITION" == "animate" ]]; then
  ANIM_JSON=$(node "$LIB_DIR/config.js" get-animation 2>/dev/null)
  STEPS=$(echo "$ANIM_JSON" | jq -r '.steps // 8')
  STEP_MS=$(echo "$ANIM_JSON" | jq -r '.step_ms // 120')

  # Set cursor + fg immediately, animate background
  [[ -n "$BLENDED_CURSOR" ]] && printf '\033]12;%s\033\\' "$BLENDED_CURSOR" > "$TARGET_TTY"
  [[ -n "$BASE_FG" ]]        && printf '\033]10;%s\033\\' "$BASE_FG" > "$TARGET_TTY"

  node "$LIB_DIR/color.js" animate "$BASE_BG" "$TINT" "$STEPS" "$STEP_MS" "$TARGET_TTY" &
  echo $! > "$ANIM_PID_FILE"
else
  # Instant transition
  [[ -n "$BLENDED_BG" ]]     && printf '\033]11;%s\033\\' "$BLENDED_BG" > "$TARGET_TTY"
  [[ -n "$BASE_FG" ]]        && printf '\033]10;%s\033\\' "$BASE_FG" > "$TARGET_TTY"
  [[ -n "$BLENDED_CURSOR" ]] && printf '\033]12;%s\033\\' "$BLENDED_CURSOR" > "$TARGET_TTY"
fi

# Record current state
STATE_FILE="/tmp/aura-state-$(echo "$TARGET_TTY" | tr '/' '_').txt"
echo "$STATE_NAME" > "$STATE_FILE"

# Handle auto-transitions (e.g., connected -> base after 1.5s)
if [[ -n "$AUTO_TO" ]] && [[ "$AUTO_MS" -gt 0 ]]; then
  AUTO_SEC=$(node -e "console.log(parseFloat(process.argv[1]) / 1000)" -- "$AUTO_MS" 2>/dev/null)
  if [[ -n "$AUTO_SEC" ]]; then
    (
      sleep "$AUTO_SEC"
      if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "$STATE_NAME" ]]; then
        "$0" "$AUTO_TO" --tty "$TARGET_TTY" --session "$SESSION_ID"
      fi
    ) &
    # Track auto-transition PID for cleanup
    AUTO_PID_FILE="/tmp/aura-auto-$(echo "$TARGET_TTY" | tr '/' '_').pid"
    echo $! > "$AUTO_PID_FILE"
  fi
fi

exit 0
