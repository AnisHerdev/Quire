# PRODUCT.md — Quire

> Your notes, everywhere.

**Version:** 0.1.0 (MVP)
**Last updated:** May 27, 2026
**Status:** Pre-development / UI ready, backend pending

---

## 1. What is Quire?

Quire is a mobile-first note organization and search app for students. It connects to the user's Google Drive, indexes their academic notes (PDF, PPT, DOCX, TXT), and lets them search across all content — not just filenames — using full-text BM25 search. Files are accessible on any device where the user signs in, and can be downloaded for offline viewing.

The name "Quire" comes from the traditional unit of paper measurement (a stack of 24-25 sheets) — reinforcing the app's identity as a digital paper organizer.

---

## 2. Why does this exist?

### The problem

Students receive notes through chaotic channels: WhatsApp groups, Telegram, scattered Google Drive links, email attachments, and local laptop storage. When they need a specific note — especially before exams — finding it is painful:

- Notes are buried in hundreds of WhatsApp messages
- Files exist only on a laptop that might be closed/off
- No way to search *inside* PDFs or PowerPoints
- No unified view across semesters and subjects
- Switching between devices means emailing files to yourself or using USB drives

### The insight

Students already organize notes in Google Drive — but Drive's built-in search is slow, doesn't index content inside files well, and has no academic structure (semester → subject → assessment). Quire doesn't replace Drive; it sits on top of it and adds structure, fast search, and mobile-first access.

### Why Google Drive (not a custom backend)?

Academic notes are often college-provided content with ambiguous copyright. Hosting them on a public server creates legal risk. By keeping everything in the user's own Google Drive:

- The user owns their data
- No copyright concerns for the app developer
- No server storage costs
- Privacy is inherent — files never leave the user's Drive except through the app

---

## 3. Who is this for?

**Primary:** College students (ages 17-24) in India who:
- Receive notes via WhatsApp/Telegram from professors and classmates
- Store notes in Google Drive or local storage
- Study from their phone (especially during commutes, in bed, on the go)
- Need to quickly find specific topics across many files before exams

**Secondary:** High school students (grades 8-12) with similar note-taking patterns.

**Key behavioral traits:**
- Already use Google Drive and Google accounts
- Comfortable with mobile apps but impatient with slow UX
- Price-sensitive (free tier must be genuinely useful)
- Organize files in folder hierarchies (semester → subject → topic)

---

## 4. Core user flows

### Flow 1: First-time setup
1. User opens Quire
2. Sees splash screen → login screen
3. Signs in with Google (Firebase Auth)
4. Sees permission explanation screen ("We only access the Quire-Notes folder")
5. Grants Drive access (OAuth, `drive.file` scope)
6. App creates `Quire-Notes` folder in user's Drive
7. Onboarding completes — user lands on Home screen

### Flow 2: Browsing notes
1. Home screen shows folder tree from `Quire-Notes`
2. User navigates: Semester 1 → Data Structures → IA1
3. Sees list of files with type icons, sizes, dates
4. Taps a PDF → opens in-app viewer
5. Uses pinch-to-zoom, scroll, night mode

### Flow 3: Searching
1. User taps search bar (available from any screen)
2. Types "binary trees"
3. Results show matching files with highlighted snippets
4. Results ranked by BM25 relevance (best match first)
5. User can filter by file type (PDF, PPT, etc.)
6. Taps result → opens file at relevant section

### Flow 4: Offline access
1. User is about to board a train with no internet
2. Taps download icon on a file
3. File is saved to local device storage
4. Later, in Offline Files screen, user can view it without internet
5. User can manage downloads (delete to free space)

### Flow 5: Adding content
1. User has files on their phone or laptop
2. Option A: Upload from phone via Quire's FAB (+) button
3. Option B: Add files directly to `Quire-Notes` folder via Drive app/website
4. Quire syncs and indexes new files automatically

---

## 5. Feature specification

### 5.1 Authentication
- **Google Sign-In** via Firebase Auth
- Single sign-on — no separate username/password
- Firebase stores: user ID, email, display name, photo URL
- Session persists across app restarts

### 5.2 Google Drive Integration
- **Scope:** `https://www.googleapis.com/auth/drive.file` (access only to files/folders created by Quire)
- **Optional broader scope:** `drive.readonly` if user wants to browse existing Drive folders
- **Auto-create folder:** `Quire-Notes` in user's Drive root on first launch
- **Operations supported:**
  - List files and folders (recursive)
  - Create folders
  - Rename folders
  - Delete folders (with confirmation)
  - Upload files (from phone storage)
  - Download files (to local cache)
  - Watch for changes (Drive Changes API for sync)
- **File types supported:**
  - PDF (text-based) — full text extraction and indexing
  - TXT — full text extraction and indexing
  - PPTX — text extraction (V2, via platform channel)
  - DOCX — text extraction (V2, via platform channel)
  - Scanned PDFs — OCR via ML Kit (V2)

### 5.3 Search
- **Engine:** SQLite FTS5 with BM25 ranking (built-in)
- **Indexed content:**
  - File names
  - Extracted text content from supported file types
  - Folder path (for context)
- **Search behavior:**
  - Full-text search across all indexed content
  - Ranked results (best match first)
  - Highlighted snippets showing match context
  - Filters: file type, folder/semester
  - Recent searches saved locally
- **Index lifecycle:**
  - Built locally on each device
  - Updated when files are added/modified/deleted
  - Rebuilt from scratch if index is corrupted or cleared
  - Typical re-index time for 500 files: < 10 seconds

### 5.4 File Viewer
- **PDF:** In-app viewer with scroll, zoom, page navigation, night mode toggle
- **TXT:** Simple text display with monospace font
- **PPTX/DOCX (MVP):** Show extracted text or prompt to open in external app
- **Toolbar:** Back, file name, share, bookmark, download

### 5.5 Offline Support
- Download individual files to app-specific storage
- Offline Files screen shows all downloaded files
- Storage indicator (used / available)
- Delete downloads to free space
- Downloaded files persist across app restarts

### 5.6 Sync
- Manual pull-to-refresh on Home screen
- Background sync on app launch (check for changes since last sync)
- Drive Changes API used to detect modifications
- Sync status indicator (last synced time)

---

## 6. Screens

| # | Screen | Purpose |
|---|--------|---------|
| 1 | Splash | Brand intro, auto-navigate to login or home |
| 2 | Login | Google sign-in, app introduction |
| 3 | Onboarding | Permission explanation, Drive setup |
| 4 | Home | Folder tree browse, search bar, FAB |
| 5 | File List | Files within a folder, sort, actions |
| 6 | Search | Search bar, filters, results with snippets |
| 7 | Viewer | In-app PDF/TXT viewer with toolbar |
| 8 | Offline Files | Downloaded files, storage management |
| 9 | Profile/Settings | Account info, Drive path, dark mode, sign out |

---

## 7. Design Language

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Primary | `#1B4332` | Headers, active states, buttons |
| Primary Light | `#2D6A4F` | Secondary buttons, hover states |
| Primary Lighter | `#52B788` | Success states, accents |
| Accent | `#D4A843` | Highlights, search term emphasis, badges |
| Background Light | `#FAF9F4` | Light mode background |
| Background Dark | `#1A1A2E` | Dark mode background |
| Surface Light | `#FFFFFF` | Cards, modals |
| Surface Dark | `#16213E` | Cards, modals (dark) |
| Text Primary Light | `#1A1A1A` | Body text (light mode) |
| Text Primary Dark | `#E8E8E8` | Body text (dark mode) |
| Text Secondary | `#6B7280` | Captions, metadata |
| Error | `#E05252` | Error states, delete actions |

### Typography
- **UI Font:** Inter (all interface text, buttons, labels)
- **Content Font:** Lora (headings, viewer mode — reinforces paper/academic feel)
- **Base size:** 16px
- **Scale:** 12px / 14px / 16px / 20px / 24px / 32px

### Spacing
- **Base unit:** 8px
- **Scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48

### Shapes
- **Border radius:** 12px (cards), 16px (buttons), 24px (FAB, search bar)
- **Shadows:** Soft, warm-tinted (not cool gray)

### Icons
- Rounded/outlined style
- 24px default size
- File type icons color-coded: PDF=red, PPT=orange, DOCX=blue, TXT=green

### Bottom Navigation
- 4 tabs: Home | Search | Offline | Profile
- Active state: Primary color with label
- Inactive state: Secondary text color

---

## 8. Technical Architecture

### Stack
- **Framework:** Flutter (Dart)
- **State management:** Riverpod (recommended) or Provider
- **Backend:** Firebase (Auth, Firestore for metadata)
- **Cloud storage:** Google Drive API v3
- **Local database:** SQLite (via `sqflite` package) with FTS5
- **PDF viewing:** `pdfrx` or `syncfusion_flutter_pdfviewer`
- **Text extraction:** `syncfusion_flutter_pdf` (PDF), platform channel (PPTX/DOCX in V2)
- **OCR (V2):** Google ML Kit Text Recognition

### Data flow
```
Google Drive (source of truth for files)
    ↓ Drive API
Flutter App
    ├── Firebase Auth (user identity)
    ├── Firestore (metadata: bookmarks, sync state, recent files)
    ├── SQLite FTS5 (local search index)
    └── Local file cache (offline downloads)
```

### Key packages
```yaml
dependencies:
  flutter: ^3.x
  firebase_core: ^3.x
  firebase_auth: ^5.x
  google_sign_in: ^6.x
  googleapis: ^13.x
  googleapis_auth: ^1.x
  sqflite: ^2.x
  path_provider: ^2.x
  pdfrx: ^1.x
  syncfusion_flutter_pdfviewer: ^27.x
  riverpod: ^2.x
  go_router: ^14.x
  cached_network_image: ^3.x
  share_plus: ^10.x
  url_launcher: ^6.x
  flutter_secure_storage: ^9.x
```

---

## 9. MVP Scope (what we're building first)

**Included:**
- Google Sign-In + Drive OAuth
- Auto-create `Quire-Notes` folder
- Folder tree browsing
- File listing with type icons
- PDF and TXT text extraction + indexing
- SQLite FTS5 BM25 search with highlighted snippets
- In-app PDF viewer
- Offline file download
- Dark mode
- All 9 screens from the design spec

**NOT in MVP (V2+):**
- PPTX/DOCX text extraction
- OCR for scanned PDFs
- AI summaries
- Sharing/collaboration
- Web app
- Push notifications
- Analytics

---

## 10. Success metrics (how we know it's working)

- **Setup completion rate:** % of users who complete onboarding and grant Drive access (target: >70%)
- **Search usage:** Average searches per user per week (target: >5)
- **Offline usage:** % of users who download at least one file (target: >40%)
- **Retention:** % of users who return after 7 days (target: >50%)
- **Play Store rating:** Target 4.0+ within first 100 reviews

---

## 11. Competitive landscape

| App | What it does | What Quire does better |
|-----|-------------|----------------------|
| Google Drive | File storage + basic search | Full-text content search, academic structure, offline-first mobile UX |
| Files by Google | Local file management | Cloud sync, cross-device, content search |
| Notion | Note-taking + database | Zero setup (uses existing Drive files), no manual note entry |
| Obsidian | Local markdown notes | No markdown requirement, works with existing PDFs/PPTs |
| StudyX / Doubtnut | Pre-made notes | User's own notes, privacy-first, no content licensing |

**Quire's moat:** It doesn't ask students to change their workflow. They already have files in Drive. Quire just makes those files searchable and accessible.

---

## 12. Risks and mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Users won't grant Drive permissions | High | Clear permission screen, minimal scope, explain "we only see Quire-Notes folder" |
| Text extraction fails on complex PDFs | Medium | Fallback to filename-only indexing, OCR in V2 |
| Slow sync on large file collections | Medium | Incremental sync via Changes API, background processing |
| User organizes folders differently than expected | Low | App is structure-agnostic; search works regardless of folder hierarchy |
| Google Drive API rate limits | Low | Batch requests, exponential backoff, cache aggressively |
| Play Store rejection for Drive access | Low | Follow Google's OAuth verification process, clear privacy policy |

---

## 13. Monetization (future)

- **Free tier:** Up to 200 indexed files, basic search, PDF viewer
- **Pro tier (₹99-199/month):** Unlimited files, PPTX/DOCX indexing, OCR, AI summaries, priority sync
- **Target conversion:** 3-5% of active users (typical for utility apps)

---

## 14. Open questions / decisions pending

1. **State management:** Riverpod vs Provider? (Recommendation: Riverpod for type safety and testability)
2. **Routing:** GoRouter vs Navigator 2.0? (Recommendation: GoRouter for deep linking support)
3. **Firestore usage:** Minimal (just bookmarks + sync state) or more aggressive (cache file metadata)?
4. **Index storage:** Store SQLite DB in app documents directory (default) — confirm no need for external storage
5. **Minimum Android API:** API 24 (Android 7.0) to cover 95%+ of devices

---

## 15. Glossary

| Term | Meaning |
|------|---------|
| Quire | A stack of 24-25 paper sheets; also the app name |
| FTS5 | SQLite Full-Text Search extension #5, uses BM25 ranking |
| BM25 | Best Match 25 — a ranking algorithm for full-text search |
| Drive.file scope | OAuth scope that limits access to files created by the app |
| Firestore | Firebase's NoSQL cloud database (used for metadata only) |
| OAuth | Open Authorization — the protocol for granting app access to Google services |
| Platform channel | Flutter mechanism for calling native Android/iOS code |