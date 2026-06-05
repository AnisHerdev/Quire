#!/bin/bash
# One-time setup: make /snap/command-chain/ writable for current user.
# Required because snapcraft's gnome extension writes desktop-launch there.
echo "Before: $(stat -c '%U:%G %a' /snap/command-chain/)"
sudo chown "$(id -u):$(id -g)" /snap/command-chain/
echo "After:  $(stat -c '%U:%G %a' /snap/command-chain/)"

# Also flush any stale Docker nftables rules (LXD + Docker conflict on Ubuntu 24.04)
sudo nft delete table ip filter 2>/dev/null
sudo nft delete table ip nat 2>/dev/null
sudo nft delete table ip6 filter 2>/dev/null
sudo nft delete table ip6 nat 2>/dev/null
sudo nft flush table ip filter 2>/dev/null
sudo nft flush table ip nat 2>/dev/null
sudo nft flush table ip6 filter 2>/dev/null
sudo nft flush table ip6 nat 2>/dev/null
echo "Docker nftables flushed (if any)"

echo
echo "=== Now run: bash /home/aninit/Downloads/Anish/Quire/scripts/build-snap.sh ==="
