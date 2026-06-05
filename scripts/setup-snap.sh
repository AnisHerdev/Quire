#!/bin/bash
# One-time setup: make /snap/command-chain/ writable for current user.
# Required because snapcraft's gnome extension writes desktop-launch there as root.
#
# Uses SUDO_UID/SUDO_GID so it works correctly when invoked as 'sudo bash setup-snap.sh'.

# Capture original user (set by sudo) or fall back to current user if not under sudo
ORIG_UID="${SUDO_UID:-$(id -u)}"
ORIG_GID="${SUDO_GID:-$(id -g)}"

# Ensure the directory is ours
sudo chown "$ORIG_UID:$ORIG_GID" /snap/command-chain/

# Also chown any existing file (snapcraft recreates it as root each run)
if [ -f /snap/command-chain/desktop-launch ]; then
  sudo chown "$ORIG_UID:$ORIG_GID" /snap/command-chain/desktop-launch
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
