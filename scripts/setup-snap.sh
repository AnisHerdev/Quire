#!/bin/bash
# One-time setup: make /snap/command-chain/ writable for current user.
# Required because snapcraft's gnome extension writes desktop-launch there as root.

# Ensure the directory is ours
sudo chown "$(id -u):$(id -g)" /snap/command-chain/

# Also chown any existing file (snapcraft recreates it as root each run)
if [ -f /snap/command-chain/desktop-launch ] && [ "$(stat -c '%U' /snap/command-chain/desktop-launch)" != "$(id -un)" ]; then
  echo "Fixing root-owned desktop-launch..."
  sudo chown "$(id -u):$(id -g)" /snap/command-chain/desktop-launch
fi

# Also flush any stale Docker nftables rules (LXD + Docker conflict on Ubuntu 24.04)
sudo nft delete table ip filter 2>/dev/null
sudo nft delete table ip nat 2>/dev/null
sudo nft delete table ip6 filter 2>/dev/null
sudo nft delete table ip6 nat 2>/dev/null
sudo nft flush table ip filter 2>/dev/null
sudo nft flush table ip nat 2>/dev/null
sudo nft flush table ip6 filter 2>/dev/null
sudo nft flush table ip6 nat 2>/dev/null
echo "=== Ready. Run: bash /home/aninit/Downloads/Anish/Quire/scripts/build-snap.sh ==="
