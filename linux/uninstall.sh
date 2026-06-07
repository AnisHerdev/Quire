#!/usr/bin/env bash
set -euo pipefail

PURGE_DATA=false
ASSUME_YES=false

usage() {
  cat <<EOF
Usage: ./uninstall.sh [options]

Removes the Quire desktop integration installed by install.sh.

Options:
  --purge-data    Also remove runtime data (cache, sync state) located in
                  ~/.local/share/quire/. Note: secure-storage tokens are kept
                  in the OS keyring and must be cleared manually.
  -y, --yes       Skip confirmation prompt.
  -h, --help      Show this help and exit.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-data) PURGE_DATA=true; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

DESKTOP_FILE="$HOME/.local/share/applications/quire.desktop"
ICON_FILE="$HOME/.local/share/icons/hicolor/256x256/apps/quire.png"
DATA_DIR="$HOME/.local/share/quire"
APPS_DIR="$HOME/.local/share/applications"

INTEGRATION_FOUND=false
BUNDLE_PATH=""

if [ -f "$DESKTOP_FILE" ]; then
  INTEGRATION_FOUND=true
  BUNDLE_PATH="$(grep -m1 '^Exec=' "$DESKTOP_FILE" \
    | sed -e 's/^Exec=//' \
          -e 's/[[:space:]]%[a-zA-Z]*$//')"
fi
if [ -f "$ICON_FILE" ]; then
  INTEGRATION_FOUND=true
fi

DATA_EXISTS=false
if [ -d "$DATA_DIR" ]; then
  DATA_EXISTS=true
fi

if ! $INTEGRATION_FOUND && ! $DATA_EXISTS && ! $PURGE_DATA; then
  echo "Nothing to uninstall — no Quire desktop entry or icon found."
  exit 0
fi

echo "The following actions will be performed:"
echo ""

if [ -f "$DESKTOP_FILE" ]; then
  echo "  [remove]  $DESKTOP_FILE"
fi
if [ -f "$ICON_FILE" ]; then
  echo "  [remove]  $ICON_FILE"
fi
if $PURGE_DATA && [ -d "$DATA_DIR" ]; then
  echo "  [remove]  $DATA_DIR  (runtime data)"
fi
echo "  [refresh] desktop and icon caches"

if [ -n "$BUNDLE_PATH" ]; then
  echo ""
  echo "Note: the Quire bundle itself will NOT be removed."
  echo "      The desktop entry points to: $BUNDLE_PATH"
  echo "      Delete that directory manually if you no longer need it."
fi

if [ -e "/snap/bin/quire" ] || [ -e "/var/lib/snapd/snap/bin/quire" ]; then
  echo ""
  echo "Note: a snap installation was also detected."
  echo "      To remove the snap, run: sudo snap remove quire"
fi

echo ""

if ! $ASSUME_YES; then
  read -r -p "Proceed? [y/N] " response
  case "$response" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

for f in "$DESKTOP_FILE" "$ICON_FILE"; do
  if [ -f "$f" ]; then
    rm -f "$f"
  fi
done

if $PURGE_DATA && [ -d "$DATA_DIR" ]; then
  rm -rf "$DATA_DIR"
  echo "Removed runtime data at $DATA_DIR"
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
fi

echo ""
echo "Uninstall complete."
