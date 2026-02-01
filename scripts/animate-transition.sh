#!/bin/bash
# ghostty-radiant: Smooth color interpolation between two background colors
# Usage: animate-transition.sh <tty_path> <start_bg> <end_bg> <cursor_color> <steps> <step_ms>
#
# Ping-pongs between start and end bg colors, writing OSC 11 to the target TTY.
# Runs in foreground (caller backgrounds it and saves PID).

TARGET_TTY="$1"
START_BG="$2"
END_BG="$3"
CURSOR="$4"
STEPS="${5:-8}"
STEP_MS="${6:-120}"

STEP_SEC=$(echo "scale=3; $STEP_MS / 1000" | bc)

trap "exit 0" TERM INT

# Convert #RRGGBB to decimal components
hex_to_rgb() {
  local hex="${1#\#}"
  echo "$((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))"
}

rgb_to_hex() {
  printf "#%02x%02x%02x" "$1" "$2" "$3"
}

lerp() {
  # lerp(start, end, t) where t is 0..STEPS
  echo $(( $1 + ($2 - $1) * $3 / $4 ))
}

read SR SG SB <<< $(hex_to_rgb "$START_BG")
read ER EG EB <<< $(hex_to_rgb "$END_BG")

# Set cursor once
if [[ -n "$CURSOR" ]] && [[ -w "$TARGET_TTY" ]]; then
  printf '\033]12;%s\033\\' "$CURSOR" > "$TARGET_TTY"
fi

direction=1
step=0

while true; do
  R=$(lerp $SR $ER $step $STEPS)
  G=$(lerp $SG $EG $step $STEPS)
  B=$(lerp $SB $EB $step $STEPS)
  HEX=$(rgb_to_hex $R $G $B)

  if [[ -w "$TARGET_TTY" ]]; then
    printf '\033]11;%s\033\\' "$HEX" > "$TARGET_TTY"
  else
    exit 0
  fi

  sleep "$STEP_SEC"

  step=$((step + direction))
  if [[ $step -ge $STEPS ]]; then
    direction=-1
    step=$STEPS
  elif [[ $step -le 0 ]]; then
    direction=1
    step=0
  fi
done
