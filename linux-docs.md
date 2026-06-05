# Building & Uploading Quire (Linux Snap)

This guide covers building the Quire snap locally and uploading it to the Snap Store from an Ubuntu 24.04 host.

## Prerequisites

- Ubuntu 24.04 (or any host that can run LXD)
- LXD installed and initialized: `sudo snap install lxd && sudo lxd init --auto`
- User in the `lxd` group: `sudo usermod -a -G lxd $USER` (then `newgrp lxd` in a new shell)
- Snapcraft installed: `sudo snap install snapcraft --classic`
- A `.env` file with Firebase + Google OAuth credentials (see `.env.example`)

## One-time Setup

```bash
# 1. Make /snap/command-chain/ writable for your user
#    (snapcraft's gnome extension writes desktop-launch there as root)
sudo bash scripts/setup-snap.sh
```

## Build the Snap

```bash
bash scripts/build-snap.sh
```

This will:
1. Launch a **privileged `ubuntu:22.04` LXD container** (matches `core22` GLIBC 2.35; has a working DHCP client)
2. Install Flutter 3.44.1 + Linux build dependencies
3. Run `flutter pub get` and `flutter build linux --release`
4. Clean snapcraft's `parts/prime/stage/` (root-owned from prior runs)
5. Run `snapcraft pack --destructive-mode` on the host to produce `quire_<version>_amd64.snap`

The script exits with the path to the snap.

> **Why LXD + a privileged container?** Snapcraft's `craft-com.ubuntu.cloud-buildd:core22` base image (used by `snapcraft --use-lxd`) lacks a DHCP client, so containers can't reach the internet. The regular `ubuntu:22.04` image has a DHCP client and works. A privileged container is needed so the bind-mounted `/build` is writable when the container's root writes build artifacts (otherwise the unprivileged UID map would block writes to host files).

> **Why a separate LXD container for the Flutter build instead of snapcraft's provider?** Snapcraft's `--use-lxd` provider still uses the broken `craft-com.ubuntu.cloud-buildd:core22` base. By doing the Flutter build manually in a `ubuntu:22.04` container and letting snapcraft just pack the pre-built binary (`plugin: nil` + `override-build` that copies files), we sidestep the broken base entirely.

## Install Locally (test the snap)

```bash
sudo snap install --dangerous quire_<version>_amd64.snap
snap run quire
```

If you see `EGL` / `libEGL` errors when launching, the snap's OpenGL/Mesa stack isn't being picked up. Check that `extensions: [gnome]` is present in `snap/snapcraft.yaml` and that the host has `gnome-42-2204` snap installed (`snap list gnome-42-2204`).

To uninstall:
```bash
sudo snap remove quire
```

## Upload to the Snap Store

```bash
# Login (first time only — opens a browser to authorize)
snapcraft login

# Upload to edge first (recommended for new snaps — skips manual review)
snapcraft upload quire_<version>_amd64.snap --release=edge

# Test the edge channel locally:
sudo snap install quire --channel=edge
snap run quire

# After verifying edge works, promote to stable
snapcraft release quire <revision> stable
```

> **Why edge first?** Snapcraft does an automatic scan + (sometimes) manual review on the first upload to `stable`. The first upload to `edge` is reviewed automatically only, so you can verify the snap works on real users before going to `stable`. After the first successful stable review, subsequent uploads to `stable` are usually automatic.

> **Note on duplicate uploads:** Snapcraft rejects uploads of an identical binary (`binary_sha3_384` collision). If you re-upload the same content, bump the version in `snap/snapcraft.yaml` and `pubspec.yaml` before rebuilding.

## Common Issues

### LXD container can't reach the internet
If `apt-get update` inside an LXD container times out, Docker's nftables rules are likely stale. Run:
```bash
sudo nft delete table ip filter
sudo nft delete table ip nat
sudo nft delete table ip6 filter
sudo nft delete table ip6 nat
```
Or just re-run `scripts/setup-snap.sh` which does this.

### `Permission denied: /snap/command-chain/desktop-launch`
snapcraft created the file as root (it runs as a snap). Re-run `sudo bash scripts/setup-snap.sh` to chown it back to your user.

### `DESIGN.json: Permission denied` / `parts/quire/build: Permission denied`
`parts/`, `prime/`, `stage/` are root-owned from a previous build. The build script cleans them automatically using a privileged LXD container. If they still get stuck, manually:
```bash
sudo rm -rf parts prime stage
```

### GLIBC errors during `snapcraft` lint
Warnings like `version 'GLIBC_2.38' not found` are from the linter checking bundled libraries — they're warnings, not errors. The snap is still produced.

### Snap Store rejection: `password-manager-service` plug
The Snap Store auto-rejects this plug for non-password-manager apps. Don't add it to `snap/snapcraft.yaml`. `flutter_secure_storage` uses modern `libsecret` which auto-uses the Secret Portal via the `desktop` plug (already in the yaml).

### Snap Store rejection: `check_squashfs_fragments` / `'-no-fragments'`
Modern snapcraft handles this automatically. If you see this, update snapcraft:
```bash
sudo snap refresh snapcraft
```

## CI / GitHub Actions

`.github/workflows/build-linux.yml` builds the Linux bundle (`build/linux/x64/release/bundle/`) on every push and uploads it as a workflow artifact. The snap build itself is **not** in CI because:
- It needs LXD + a one-time sudo chown
- Local builds are faster and let you test the snap before uploading
- Snap Store uploads are intentionally a manual step
