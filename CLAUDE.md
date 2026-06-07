# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

**Quire** — "Your notes, everywhere." A Flutter-based note organization and search app for students. Connects to the user's Google Drive, indexes academic notes (PDF, PPT, DOCX, TXT), and provides full-text BM25 search. Files stay in the user's own Google Drive (privacy-first, no server storage costs).

**Current version:** 1.0.0+1 | **Platforms:** Android, iOS, Linux (desktop)

## Build Commands

### General
```bash
flutter pub get                          # Install dependencies
flutter analyze                          # Run static analysis
flutter test                             # Run tests
```

### Linux (primary desktop target)
```bash
flutter config --enable-linux-desktop    # Enable Linux desktop
flutter build linux --release            # Release build
```
The Linux build requires: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev patchelf`

### Snap build (runs in core22 LXD container — no Docker needed)
```bash
# One-time setup
sudo snap install snapcraft --classic
sudo snap install lxd
sudo lxd init --auto
sudo usermod -a -G lxd $USER
# Log out and back in (or: newgrp lxd)

# Every build
bash scripts/build-snap.sh
# Equivalent: source .env && export dart-define vars && snapcraft --use-lxd
```
The snap recipe is in `snap/snapcraft.yaml`. Uses `extensions: [gnome]` which generates Mesa/EGL command chains. All six dart-define values must be set as environment variables.

### Linux build with dart-defines (required for OAuth)
```bash
flutter build linux --release \
  --dart-define=FIREBASE_API_KEY_QUIRE="..." \
  --dart-define=FIREBASE_APP_ID_QUIRE="..." \
  --dart-define=FIREBASE_SENDER_ID_QUIRE="..." \
  --dart-define=FIREBASE_PROJECT_ID_QUIRE="..." \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID_QUIRE="..." \
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET_QUIRE="..."
```

### Android / iOS
Standard Flutter build commands apply. Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) are gitignored and must be present locally.

## Architecture

### State Management
**Riverpod** (`flutter_riverpod`). Providers are in `lib/providers/`. The router watches `authProvider` for auth state changes.

### Routing
**GoRouter** (`go_router`). Routes defined in `lib/routes/app_router.dart`. Auth redirect logic is inline in the router provider — unauthenticated users get redirected to `/login`, authenticated users get redirected away from auth screens to `/home`.

### Key Services
| Service | File | Purpose |
|---------|------|---------|
| `AuthService` | `lib/services/auth_service.dart` | Google Sign-In via Firebase (mobile) or OAuth consent flow (Linux). Uses `flutter_secure_storage` for token persistence. |
| `DriveService` | `lib/services/drive_service.dart` | Google Drive API v3 — file/folder CRUD, upload/download, search, thumbnails. Supports both `GoogleSignInAccount` (mobile) and raw access token (Linux). |
| `CacheService` | `lib/services/cache_service.dart` | Local file caching for offline access |
| `SyncService` | `lib/services/sync_service.dart` | Drive sync logic |
| `SharingService` | `lib/services/sharing_service.dart` | Receive shared content from other apps |

### Auth Platform Split
`AuthService` has a **platform split**: on Linux it uses raw OAuth 2.0 via `googleapis_auth` (no Firebase), on mobile it uses `FirebaseAuth` + `GoogleSignIn`. The `Platform.isLinux` check gates Firebase initialization in `main.dart` (line 12).

### Data Models
- `lib/models/user_model.dart` — User profile
- `lib/models/file_model.dart` — Drive file representation
- `lib/models/note_file_model.dart` — Note file with metadata
- `lib/models/database_model.dart` — Local database schema

### Theme
`lib/theme/` contains `app_colors.dart`, `app_theme.dart`, `app_typography.dart`. Uses **Lora** (serif, headings) + **Inter** (sans-serif, UI text) via `google_fonts`. Supports light/dark mode via `themeProvider`.

## Linux Desktop Details

### Application ID
`com.example.quire` — set in `linux/CMakeLists.txt` as `APPLICATION_ID`. This is used by GTK for desktop file mapping and window identification.

### Existing Linux Files
- `linux/install.sh` — User-facing install script that copies icon + desktop entry to `~/.local/share/`
- `linux/uninstall.sh` — User-facing uninstall script that reverses `install.sh` (removes the desktop entry and icon, with an optional `--purge-data` flag for runtime data)
- `linux/quire.desktop` — Desktop entry template (uses `EXEC_PATH_PLACEHOLDER` replaced at install time)
- `linux/CMakeLists.txt` — Build config; includes patchelf RPATH fix for bundled `.so` files
- `assets/images/logo.png` — App icon (256x256)

### CI/CD
GitHub Actions workflow at `.github/workflows/build-linux.yml` builds on `ubuntu-latest`, bundles `install.sh`, `quire.desktop`, and `logo.png` into the artifact.

## Environment / Secrets

The app requires these `--dart-define` values at build time:
- `FIREBASE_API_KEY_QUIRE`
- `FIREBASE_APP_ID_QUIRE`
- `FIREBASE_SENDER_ID_QUIRE`
- `FIREBASE_PROJECT_ID_QUIRE`
- `GOOGLE_OAUTH_CLIENT_ID_QUIRE`
- `GOOGLE_OAUTH_CLIENT_SECRET_QUIRE`

These are stored as GitHub Secrets and injected during CI builds. For local development, pass them manually or use a script.

## Key Conventions
- All file paths use forward slashes (project is developed cross-platform, shell is bash)
- Snap Store packaging is in `snap/` — see `snap/snapcraft.yaml` for the build recipe and `snap/gui/` for the desktop entry and icon. Build locally with `bash scripts/build-snap.sh` (uses `snapcraft --use-lxd` with core22 LXD container).
- `APPLICATION_ID` in `linux/CMakeLists.txt` is `com.quire.app`
