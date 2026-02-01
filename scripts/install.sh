#!/bin/bash
# ghostty-radiant: Install theme and config
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Installing ghostty-radiant..."

# 1. Install Ghostty theme
GHOSTTY_THEMES_DIR="${HOME}/.config/ghostty/themes"
mkdir -p "$GHOSTTY_THEMES_DIR"
cp "$PLUGIN_ROOT/themes/radiant" "$GHOSTTY_THEMES_DIR/radiant"
echo "  Installed theme to $GHOSTTY_THEMES_DIR/radiant"

# 2. Install config if not already present
CONFIG_DEST="${HOME}/.claude/radiant-theme.json"
if [[ ! -f "$CONFIG_DEST" ]]; then
  cp "$PLUGIN_ROOT/radiant-theme.json" "$CONFIG_DEST"
  echo "  Installed config to $CONFIG_DEST"
else
  echo "  Config already exists at $CONFIG_DEST (skipping)"
fi

# 3. Make scripts executable
chmod +x "$PLUGIN_ROOT"/scripts/*.sh
echo "  Made scripts executable"

echo ""
echo "Done! To use the radiant theme in Ghostty, add to your ghostty config:"
echo "  theme = radiant"
echo ""
echo "Hooks are registered via hooks/hooks.json (Claude Code plugin system)."
echo "To test manually:"
echo "  $PLUGIN_ROOT/scripts/set-theme-state.sh working"
echo "  $PLUGIN_ROOT/scripts/set-theme-state.sh base"
echo "  $PLUGIN_ROOT/scripts/set-theme-state.sh restore"
