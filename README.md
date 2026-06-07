# Quire

Your notes, everywhere. A note organization and search app for students.

[![snap store](https://img.shields.io/badge/Snap-Store-82BFA1?logo=snapcraft&logoColor=white)](https://snapcraft.io/quire)

## Linux Build

A pre-built Linux bundle can be downloaded from the **Actions** tab on GitHub
(the "Build Linux" workflow → latest run → **linux-bundle** artifact).

### Quick Start

```bash
# 1. Install runtime dependencies
sudo apt install libgtk-3-0 libsecret-1-0 liblzma5

# 2. Extract the bundle
unzip linux-bundle.zip -d quire

# 3. Run it
./quire/quire
```

The first sign-in will open your browser for Google OAuth. Subsequent launches
use a stored refresh token for silent re-authentication.

### Install (App Menu Entry)

To add Quire to your application menu with an icon:

```bash
cd quire
chmod +x install.sh
./install.sh
```

This will:
- Install the app icon to `~/.local/share/icons/hicolor/256x256/apps/`
- Add a desktop entry to `~/.local/share/applications/`
- Update the desktop database so Quire appears in your app launcher

After running, you can find "Quire" in your application menu and pin it
to your dock/taskbar for one-click launch.

If you move the bundle to a different location, re-run `install.sh` to
update the path in the desktop entry.

### Uninstall

To remove the desktop entry and icon installed by `install.sh`:

```bash
cd quire
chmod +x uninstall.sh
./uninstall.sh
```

By default this only removes the menu integration (desktop file + icon).
To also wipe cached notes and sync state, pass `--purge-data`:

```bash
./uninstall.sh --purge-data
```

The Quire bundle directory itself is never deleted by the script — the
output will print its location so you can remove it manually. To
re-install, just re-run `install.sh`.

### Snap Store

Quire is also available as a snap on any Linux distribution with snap support:

```bash
sudo snap install quire
```

After installing, launch Quire from your application menu or run `quire`
in a terminal. The first sign-in will open your browser for Google OAuth.
