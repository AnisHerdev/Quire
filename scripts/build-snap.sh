#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your API keys."
  exit 1
fi

# snapcraft's gnome extension writes desktop-launch to /snap/command-chain/.
# This directory must be writable by the current user. Run scripts/setup-snap.sh once
# (requires sudo) if you see "cannot remove '/snap/command-chain/desktop-launch'".
if [ -d /snap/command-chain ] && [ ! -w /snap/command-chain ]; then
  echo "ERROR: /snap/command-chain/ is not writable. Run: sudo chown \$(id -u):\$(id -g) /snap/command-chain/"
  exit 1
fi

set -a; source .env; set +a

for var in FIREBASE_API_KEY_QUIRE FIREBASE_APP_ID_QUIRE FIREBASE_SENDER_ID_QUIRE \
           FIREBASE_PROJECT_ID_QUIRE GOOGLE_OAUTH_CLIENT_ID_QUIRE GOOGLE_OAUTH_CLIENT_SECRET_QUIRE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in .env"
    exit 1
  fi
done

# Build inside a privileged ubuntu:22.04 LXD container.
# - ubuntu:22.04 image has a working DHCP client (snapcraft's craft-com.ubuntu.cloud-buildd:core22 doesn't)
# - GLIBC 2.35 matches core22 snap base
# - privileged container root = host root, so bind-mounted files (incl. root-owned from prior Docker builds) are writable
# - this sidesteps snapcraft's --use-lxd provider entirely; we run flutter + snapcraft inside the container

CONTAINER="quire-builder-$$"
echo "=== Launching privileged LXD container: $CONTAINER ==="
sg lxd -c "lxc launch ubuntu:22.04 $CONTAINER -c security.privileged=true"
sleep 5

cleanup() {
  echo "=== Cleaning up container ==="
  sg lxd -c "lxc delete --force $CONTAINER" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for network
echo "=== Waiting for network ==="
for i in {1..30}; do
  if sg lxd -c "lxc exec $CONTAINER -- bash -c 'timeout 3 curl -sI http://archive.ubuntu.com > /dev/null 2>&1'" 2>/dev/null; then
    echo "  Network is up"
    break
  fi
  sleep 2
done

echo "=== Bind-mounting project directory ==="
sg lxd -c "lxc config device add $CONTAINER project disk source=$(pwd) path=/build"

echo "=== Installing build dependencies ==="
sg lxd -c "lxc exec $CONTAINER -- bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    curl xz-utils git unzip squashfs-tools ca-certificates \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libsecret-1-dev patchelf
'"

echo "=== Installing Flutter 3.44.1 ==="
sg lxd -c "lxc exec $CONTAINER -- bash -c '
  if [ ! -d /opt/flutter ]; then
    curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.1-stable.tar.xz -o /tmp/flutter.tar.xz
    tar xf /tmp/flutter.tar.xz -C /opt
    git config --global --add safe.directory /opt/flutter
  fi
'"

echo "=== Building Flutter app ==="
sg lxd -c "lxc exec $CONTAINER -- env \
  PATH=/opt/flutter/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  FIREBASE_API_KEY_QUIRE=\"$FIREBASE_API_KEY_QUIRE\" \
  FIREBASE_APP_ID_QUIRE=\"$FIREBASE_APP_ID_QUIRE\" \
  FIREBASE_SENDER_ID_QUIRE=\"$FIREBASE_SENDER_ID_QUIRE\" \
  FIREBASE_PROJECT_ID_QUIRE=\"$FIREBASE_PROJECT_ID_QUIRE\" \
  GOOGLE_OAUTH_CLIENT_ID_QUIRE=\"$GOOGLE_OAUTH_CLIENT_ID_QUIRE\" \
  GOOGLE_OAUTH_CLIENT_SECRET_QUIRE=\"$GOOGLE_OAUTH_CLIENT_SECRET_QUIRE\" \
  bash -c '
    flutter --disable-analytics
    flutter config --no-analytics
    cd /build
    flutter pub get
    flutter build linux --release --target-platform=linux-x64 \
      --dart-define=FIREBASE_API_KEY_QUIRE=\"$FIREBASE_API_KEY_QUIRE\" \
      --dart-define=FIREBASE_APP_ID_QUIRE=\"$FIREBASE_APP_ID_QUIRE\" \
      --dart-define=FIREBASE_SENDER_ID_QUIRE=\"$FIREBASE_SENDER_ID_QUIRE\" \
      --dart-define=FIREBASE_PROJECT_ID_QUIRE=\"$FIREBASE_PROJECT_ID_QUIRE\" \
      --dart-define=GOOGLE_OAUTH_CLIENT_ID_QUIRE=\"$GOOGLE_OAUTH_CLIENT_ID_QUIRE\" \
      --dart-define=GOOGLE_OAUTH_CLIENT_SECRET_QUIRE=\"$GOOGLE_OAUTH_CLIENT_SECRET_QUIRE\"
'"

echo "=== Packing snap (on host) ==="
# Clean snapcraft's parts/prime/stage dirs (may be root-owned from prior runs).
# The privileged container's root can access the bind-mounted /build as host root, so use it for cleanup.
# Note: do NOT clean /build/linux, /build/build, or /build/.dart_tool — Flutter needs them.
sg lxd -c "lxc exec $CONTAINER -- bash -c '
  rm -rf /build/parts /build/prime /build/stage 2>/dev/null
  rm -f /snap/command-chain/desktop-launch 2>/dev/null
  echo cleanup_done
'"

# Read version from snapcraft.yaml to produce a versioned snap filename
VERSION=$(grep '^version:' snap/snapcraft.yaml | head -1 | sed 's/version: *"\(.*\)"/\1/')
SNAP_FILE="quire_${VERSION}_amd64.snap"

# The Flutter binary is already built in /build/linux/x64/release/bundle (via bind-mount).
# snapcraft.yaml uses plugin: nil and just copies the pre-built binary, so the host's
# GLIBC doesn't matter — the binary itself was built in Ubuntu 22.04 (GLIBC 2.35, matching core22).
snapcraft pack --destructive-mode --output "$SNAP_FILE"

echo ""
echo "=== Done! ==="
ls -la "$SNAP_FILE" 2>/dev/null
echo ""
echo "Install with: sudo snap install --dangerous $SNAP_FILE"
echo "Run with:     snap run quire"
echo "Upload with:  snapcraft upload --release=stable $SNAP_FILE"
