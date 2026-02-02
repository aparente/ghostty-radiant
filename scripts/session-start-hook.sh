#!/bin/bash
# ghostty-aura: SessionStart hook
# Captures TTY path, queries current terminal colors via OSC 10/11/12,
# saves them as the "base" palette, then triggers "connected" state.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

log_err() { echo "ghostty-aura [session-start]: $*" >&2; }

# --- Capture TTY ---
TTY_PATH=$(tty 2>/dev/null || echo "")
if [[ -z "$TTY_PATH" ]] || [[ "$TTY_PATH" == "not a tty" ]]; then
  exit 0
fi

if [[ -n "$SESSION_ID" ]]; then
  echo "$TTY_PATH" > "/tmp/aura-tty-${SESSION_ID}"
fi

# --- Query current colors via OSC ---
# Send OSC query (e.g. \033]11;?\033\\) and read the terminal's response.
# Response format: \033]11;rgb:RRRR/GGGG/BBBB\033\\
# We extract the 16-bit RGB and convert to 8-bit hex.

query_osc_color() {
  local osc_code="$1"
  local response=""

  # Save terminal state, set raw mode for reading response
  local old_settings
  old_settings=$(stty -g < "$TTY_PATH" 2>/dev/null)
  stty raw -echo min 0 time 5 < "$TTY_PATH" 2>/dev/null

  # Send query
  printf '\033]%s;?\033\\' "$osc_code" > "$TTY_PATH"

  # Read response (with timeout)
  response=$(dd bs=1 count=50 < "$TTY_PATH" 2>/dev/null)

  # Restore terminal
  stty "$old_settings" < "$TTY_PATH" 2>/dev/null

  # Parse rgb:RRRR/GGGG/BBBB → #RRGGBB
  if [[ "$response" =~ rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]]; then
    local r="${BASH_REMATCH[1]}" g="${BASH_REMATCH[2]}" b="${BASH_REMATCH[3]}"
    # Take first 2 chars of each component (16-bit → 8-bit)
    printf '#%s%s%s' "${r:0:2}" "${g:0:2}" "${b:0:2}"
  else
    echo ""
  fi
}

# Query: 10=fg, 11=bg, 12=cursor
FG=$(query_osc_color 10)
BG=$(query_osc_color 11)
CURSOR=$(query_osc_color 12)

# Fallbacks if querying failed
[[ -z "$BG" ]] && BG="#1a1b26"
[[ -z "$FG" ]] && FG="#c0caf5"
[[ -z "$CURSOR" ]] && CURSOR="$FG"

# Save base colors for this session
if [[ -n "$SESSION_ID" ]]; then
  cat > "/tmp/aura-base-${SESSION_ID}.json" <<EOF
{"bg":"$BG","fg":"$FG","cursor":"$CURSOR"}
EOF
fi

# --- Check if config exists; run setup if not ---
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
if ! command -v node >/dev/null 2>&1; then
  log_err "node not found in PATH"
  exit 0
fi
if ! node "$LIB_DIR/config.js" exists 2>/dev/null; then
  # First run — generate default config silently
  CONFIG_PATH=$(node "$LIB_DIR/config.js" path)
  mkdir -p "$(dirname "$CONFIG_PATH")"
  node "$LIB_DIR/config.js" init "$CONFIG_PATH" 2>/dev/null
fi

# --- Trigger connected state ---
"$SCRIPT_DIR/set-theme-state.sh" connected --tty "$TTY_PATH" --session "$SESSION_ID"
exit 0
