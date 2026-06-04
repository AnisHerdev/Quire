#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(dirname "$SCRIPT_DIR")"

# Determine quire executable path
QUIRE_EXEC=""
if [ -f "$BUNDLE_DIR/quire" ]; then
  QUIRE_EXEC="$BUNDLE_DIR/quire"
elif [ -f "$SCRIPT_DIR/quire" ]; then
  QUIRE_EXEC="$SCRIPT_DIR/quire"
else
  echo "Error: quire executable not found. Run this script from the extracted linux-bundle directory."
  echo "  Expected: $BUNDLE_DIR/quire"
  exit 1
fi

echo "Found quire executable at: $QUIRE_EXEC"

# Icon
ICON_SRC=""
if [ -f "$SCRIPT_DIR/logo.png" ]; then
  ICON_SRC="$SCRIPT_DIR/logo.png"
elif [ -f "$BUNDLE_DIR/assets/images/logo.png" ]; then
  ICON_SRC="$BUNDLE_DIR/assets/images/logo.png"
elif [ -f "$SCRIPT_DIR/../assets/images/logo.png" ]; then
  ICON_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/assets/images/logo.png"
elif [ -f "$SCRIPT_DIR/quire.png" ]; then
  ICON_SRC="$SCRIPT_DIR/quire.png"
else
  echo "Warning: icon not found — the app will appear in the menu without an icon."
fi

ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"

if [ -n "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$ICON_DIR/quire.png"
  echo "Installed icon to $ICON_DIR/quire.png"
fi

# Desktop file
DESKTOP_SRC="$SCRIPT_DIR/quire.desktop"
DESKTOP_DST="$HOME/.local/share/applications/quire.desktop"

mkdir -p "$HOME/.local/share/applications"

sed "s|EXEC_PATH_PLACEHOLDER|$QUIRE_EXEC|g" "$DESKTOP_SRC" > "$DESKTOP_DST"
chmod +x "$DESKTOP_DST"
echo "Installed desktop entry to $DESKTOP_DST"

# Update desktop database
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$HOME/.local/share/applications/" || true
  echo "Desktop database updated."
fi

# Update icon cache
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor/" || true
  echo "Icon cache updated."
fi

echo ""
echo "Installation complete! You can now find Quire in your application menu."
echo "If it doesn't appear immediately, log out and back in."
