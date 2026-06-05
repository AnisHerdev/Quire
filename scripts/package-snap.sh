#!/usr/bin/env bash
# package-snap.sh — Assemble a .snap package from a pre-built Flutter Linux bundle.
#
# Usage:  bash scripts/package-snap.sh [bundle-dir] [output-file]
# Defaults:
#   bundle-dir: build/linux/x64/release/bundle
#   output:     quire_1.0.0_amd64.snap

set -euo pipefail

BUNDLE_DIR="${1:-build/linux/x64/release/bundle}"
OUTPUT="${2:-quire_1.0.0_amd64.snap}"
SNAP_NAME="quire"
SNAP_VERSION="1.0.0"

SNAPDIR=$(mktemp -d)
trap 'rm -rf "$SNAPDIR"' EXIT

echo "=== Assembling snap: $SNAP_NAME $SNAP_VERSION ==="
echo "  bundle: $BUNDLE_DIR"
echo "  output: $OUTPUT"

# ---------------------------------------------------------------------------
# 1.  Copy Flutter bundle
# ---------------------------------------------------------------------------
mkdir -p "$SNAPDIR/meta/gui"
cp "$BUNDLE_DIR/quire" "$SNAPDIR/"
cp -r "$BUNDLE_DIR/lib" "$SNAPDIR/"
cp -r "$BUNDLE_DIR/data" "$SNAPDIR/"

# ---------------------------------------------------------------------------
# 2.  Snap metadata  (kept in sync with snap/snapcraft.yaml)
# ---------------------------------------------------------------------------
cp snap/gui/quire.desktop "$SNAPDIR/meta/gui/"
cp snap/gui/icon.png     "$SNAPDIR/meta/gui/"

cat > "$SNAPDIR/meta/snap.yaml" << SNAPEOF
name: $SNAP_NAME
version: "$SNAP_VERSION"
summary: Your notes, everywhere — connected to Google Drive
description: |
  Quire connects to your Google Drive and indexes all your academic notes —
  PDFs, PowerPoints, Word documents, and text files. Search everything
  instantly with full-text BM25 search.
base: core22
confinement: strict
grade: stable
architectures:
  - amd64
apps:
  quire:
    command: quire
    plugs:
      - network
      - password-manager-service
      - desktop
      - desktop-legacy
      - wayland
      - x11
      - opengl
SNAPEOF

# ---------------------------------------------------------------------------
# 3.  Bundle runtime .so dependencies via ldd
# ---------------------------------------------------------------------------
# ldd catches compile-time DT_NEEDED entries.
#
# dlopen() blindspots — GTK/GIO/modules loaded at runtime will NOT appear
# here.  If the app crashes on a missing shared object after installation,
# add an explicit 'cp -L' line in the section below marked <<DLOPEN>>.
# ---------------------------------------------------------------------------
echo "  scanning ELF dependencies ..."

declare -A BUNDLED  # track already-copied sonames

collect_deps() {
    local elf="$1"
    while IFS= read -r line; do
        # Match:  soname => /path/to/lib.so  (address)
        if [[ "$line" =~ ([^[:space:]]+)[[:space:]]+'=>'[[:space:]]+'/'([^[:space:]]+) ]]; then
            soname="${BASH_REMATCH[1]}"
            resolved="/${BASH_REMATCH[2]}"

            # Skip libraries provided by the core22 base snap (glibc, ld, etc.)
            case "$soname" in
                ld-linux-*|libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|libresolv.so*|libutil.so*|libBrokenLocale*|libnss_*|libanl.so*)
                    continue ;;
            esac

            [ -f "$resolved" ] || continue
            [ -f "$SNAPDIR/lib/$soname" ] && continue

            cp -L "$resolved" "$SNAPDIR/lib/$soname"
            BUNDLED["$soname"]=1
            echo "    + $soname"
        fi
    done < <(ldd "$elf" 2>/dev/null || true)
}

# Scan the main binary first, then every .so already in the bundle
collect_deps "$SNAPDIR/quire"

# Also scan the plugin .so files — they may link additional libraries
# that the stub binary does not reference directly.
for so in "$SNAPDIR"/lib/*.so; do
    [ -f "$so" ] && collect_deps "$so"
done
for so in "$SNAPDIR"/lib/*.so.*; do
    [ -f "$so" ] && collect_deps "$so"
done

# <<DLOPEN>>  Libraries loaded via dlopen() that ldd does not see.
#             Identify missing ones via strace -e openat, then add below.
# ---------------------------------------------------------------------------
echo "  copying dlopen() dependencies ..."

for lib in libEGL.so.1 libEGL_mesa.so.0; do
    path="/usr/lib/x86_64-linux-gnu/$lib"
    if [ -f "$path" ]; then
        cp -L "$path" "$SNAPDIR/lib/$lib"
        echo "    + $lib (dlopen)"
    fi
done

# ---------------------------------------------------------------------------
# 4.  Fix RPATH so bundled .so files can find each other
# ---------------------------------------------------------------------------
# The main binary already has $ORIGIN/lib from CMakeLists.txt.  System
# libraries we just copied in have no RPATH at all — they rely on the
# default ld search paths, which don't exist inside the same way.
# Adding $ORIGIN lets them resolve transitive deps inside lib/.
# ---------------------------------------------------------------------------
echo "  fixing RPATH on bundled libraries ..."

for so in "$SNAPDIR"/lib/*.so*; do
    [ -f "$so" ] || continue
    current=$(patchelf --print-rpath "$so" 2>/dev/null || true)
    if [[ "$current" != *'$ORIGIN'* ]]; then
        if [ -n "$current" ]; then
            patchelf --set-rpath "\$ORIGIN:$current" "$so" 2>/dev/null || true
        else
            patchelf --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
        fi
    fi
done

patchelf --set-rpath '$ORIGIN/lib' "$SNAPDIR/quire" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5.  Fix permissions — snapd requires world-readable root
# ---------------------------------------------------------------------------
echo "  fixing permissions ..."
chmod 755 "$SNAPDIR"
chmod -R a+rX "$SNAPDIR"

# ---------------------------------------------------------------------------
# 6.  Pack into .snap (SquashFS)
# ---------------------------------------------------------------------------
echo "  packing snap ..."
mksquashfs "$SNAPDIR" "$OUTPUT" -comp xz -noappend -all-root 1>/dev/null

echo "=== Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1)) ==="
