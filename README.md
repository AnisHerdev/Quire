# quire

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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
