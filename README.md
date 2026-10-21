# 🌌 Epilogue (독자의 에필로그)

<p align="center">
  <img src="assets/images/orvlogo.png" alt="Epilogue Logo" width="160" />
</p>

<p align="center">
  <strong>An immersive, high-performance EPUB & Web Novel reading companion and authoring studio for Android, Linux, and Windows with Star Stream progression.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows-brightgreen.svg" alt="Platform" />
  <img src="https://img.shields.io/badge/Flutter-%3E%3D3.10.0-02569B.svg?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2.svg?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Tests-31%2F31%20Passing-success.svg" alt="Tests" />
  <img src="https://img.shields.io/badge/Analyzer-0%20Issues-brightgreen.svg" alt="Analyzer" />
  <a href="https://discord.gg/dBSRDDrNUV"><img src="https://img.shields.io/badge/Discord-Join%20Chat-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" />
</p>

<p align="center">
  <a href="https://etherealinsanity.github.io/Epilogue/"><strong>🌐 Official Website</strong></a> • 
  <a href="https://discord.gg/dBSRDDrNUV"><strong>💬 Discord Community</strong></a> • 
  <a href="https://github.com/EtherealInsanity/Epilogue/releases"><strong>📦 Download Releases (Android, Linux, Windows)</strong></a> • 
  <a href="TIME_CAPSULE.md"><strong>📜 Architecture & Capsule</strong></a>
</p>

```
[System Message: Sub-channel #BI-7623 has opened.]
[The Star Stream is broadcasting a new story.]
[The Fourth Wall is observing your reading composure.]
```

---

> *"There are three ways to survive in a ruined world. Now, I have forgotten a few. But one thing is certain: you who are reading this will survive."*  
> — **Omniscient Reader's Viewpoint**

**Epilogue** (`com.epilogue.read`) is an open-source, distraction-free reading companion and EPUB authoring studio built specifically for 500+ chapter epics, light novels, and long-running web fiction (such as *Omniscient Reader's Viewpoint*, *Lord of the Mysteries*, and *Shadow Slave*). 

Crafted with high-performance Flutter architecture, Epilogue blends a sacred, paper-pure typography engine with subtle *Star Stream* telemetry and progression mechanics.

---

## 📜 The Reading Philosophy

```
[The Fourth Wall speaks softly.]
「 T h i s   s t o r y   i s   f o r   j u s t   t h a t   o n e   r e a d e r . 」
```

Reading a 500+ chapter epic should never feel like browsing a cluttered web app. 
- **Zero Bloat & Zero Ads**: No banner ads, no login walls, no analytics trackers, and zero telemetry leaving your device.
- **The Sacred Reading Aesthetic**: Pure paper typography (`#FFFFFF` background with `#111827` deep ink text), customizable serif and sans-serif fonts, precise line-height, and margin tuning.
- **Dynamic Theming Suite**: Switch smoothly across **Paper Light**, **Sepia Warm**, **Slate Gray**, **OLED Dark**, or **The Fourth Wall** mode.
- **The Fourth Wall Shield**: System-wide deep midnight blue (`#0A192F` or custom hex) with luminescent cyan glows, color-matched palette chips, and authentic Star Stream skill notifications.

---

## 📖 The Sacred Reading Engine

```
[System Window: ModernReaderScreen Engine Active]
[Layout Math: Viewport Capacity Budgeted Dynamically]
```

### 📐 Dynamic Viewport Character Budgeting
Most mobile readers suffer from a frustrating flaw on modern tall smartphones (20:9 and 21:9 aspect ratios): up to 40% of the lower screen is left blank because of hardcoded character budgets.
- Epilogue uses a live `LayoutBuilder` geometry engine that dynamically computes line capacity and character limits based on your screen height, font size, and line spacing:
  $$\text{Budget} = \lfloor \text{Usable Height} / \text{Line Height} \rfloor \times \lfloor \text{Usable Width} / (\text{Font Size} \times 0.52) \rfloor$$
- Text breaks cleanly at paragraph and sentence endings, completely filling the screen from top to bottom.

### 🎨 Original Book Styling (EPUB CSS Engine)
- Extracts embedded EPUB stylesheets and `<style>` blocks on-the-fly.
- Faithfully renders headers (`<h1>`–`<h6>`), dividers, centered dialogue, and author blockquotes without stripping formatting into plain text.
- Top-level block element parser (`<p>`, `<div>`, `<blockquote>`, `<hr>`) guarantees HTML tags are **never torn in half** across page flips.

### 🖼️ Inline Image Pinch-to-Zoom
- Embedded chapter illustrations, world maps, and character profiles feature interactive multi-touch pinch-to-zoom (0.8x to 4.0x) powered by `InteractiveViewer`.

### 🔄 Dual Reading Modes & TOC Auto-Scroll
- **Continuous Scroll Mode**: Granular scroll position tracking with seamless chapter boundaries.
- **Dynamic Page-Turn Mode**: Tactile page navigation with left/right tap zones and in-depth reading progress.
- **TOC Auto-Scroll**: Opening the Table of Contents automatically scrolls directly to your currently active chapter.

### 📺 Retro CRT Scanline Shader
- Includes a custom GLSL fragment shader (`shaders/crt.frag`) that adds an optional vintage CRT scanline overlay, giving your text a cyberpunk, retro-terminal ambiance.

---

## ✍️ Epilogue Studio (EPUB Authoring Suite)

```
[System Window: Epilogue Studio Engaged]
[Pre-Flight Validator: EPUB 3.3 Strict Standards Active]
```

Epilogue isn't just for reading epics—it empowers authors and curators to write, edit, and package standard-compliant EPUBs right from desktop or mobile.

- **Tri-Mode Chapter Editor**: Seamlessly toggle between **Visual WYSIWYG**, **Markdown**, and **Raw XHTML/CSS Source Inspector** with a sticky formatting toolbar for headings, dialogue, blockquotes, and scene dividers.
- **Genre Templates**: Pre-configured typography and layout defaults for *Classic Literature*, *Light Novels & Fantasy*, and *Non-Fiction / Reference*.
- **Pre-Flight EPUB Linter**: Built-in validator inspecting tag closures, XHTML strictness, and UUID metadata compliance with **1-click auto-repair**.
- **Spine Hierarchy & Drag-and-Drop**: Easily reorder chapters, view live word counts, detect duplicate identifiers, and manage volume hierarchies.
- **1-Click Packaging & Export**: Produces compliant EPUB 3.3 and EPUB 2 NCX packages with uncompressed `mimetype` and clean manifest tables.
- **Clean & Optional**: Epilogue Studio is off by default to maintain a distraction-free reader interface, and can be enabled anytime via *Settings > Reading Engine & Controls*.

---

## 🌌 The Star Stream Progression System

Epilogue weaves your real-world reading habits into the lore of the Star Stream, rewarding you for every page, chapter, and volume consumed.

```
[The Constellation, 'Demon King of Salvation', is looking at your story.]
[The Constellation, 'Secretive Plotter', is silent.]
[The Constellation, 'Prisoner of the Golden Headband', is scratching his head.]
```

### ⚔️ 150+ Canonical Scenarios
- **Main Scenarios**: Progress naturally as you read chapters and complete novels.
- **Bounty Quests**: Timed and milestone-driven reading challenges.
- **Hidden Scenarios**: Discovered through marathon reading sessions, obscure book imports, and night-reading streaks.
- Earn **Coins** for completing scenarios to unlock constellation titles and attributes.

### 👑 234 Constellation Modifiers
- Attain legendary modifiers by clearing reading milestones:
  - *Demon King of Salvation*
  - *Secretive Plotter*
  - *Prisoner of the Golden Headband*
  - *Abyssal Black Flame Dragon*
  - *Demonic Judge of Fire*

### 📜 45 Canonical Fables
- Complete entire novel volumes and reach word-count marathons to acquire story fables:
  - *King of a Kingless World*
  - *Torch That Swallowed the Myth*
  - *Season of Light and Darkness*
  - *One Who Opposes the Miracle*

### 🔥 Streak Restore & Manual Telemetry Import
- **Reading Streak Restore (🪙 10K Coins)**: Missed a day? Spend 10,000 Coins from your Star Stream reserves to repair your streak.
- **Manual Reading Telemetry**: Import past reading stats and historical streak days with full verification.

### 🌀 Retrocognition (과거 회상 — Worldline Sync)

```
[System: Retrocognition sequence initiated.]
[Recalculating past story worldlines...]
```
- Migrating to Epilogue with an existing library? The built-in **Retrocognition** engine scans your entire EPUB collection, calculates total words read across chapters, estimates reading duration, and synchronizes your lifetime telemetry.
- Instantly back-credits your earned Coins, clears historical Scenarios, and unlocks your rightful Fables and Constellation Modifiers.

### 🖍️ 5 Star Stream Highlighting Palettes
Color-code memorable quotes with authentic constellation palettes:
- 🔷 **Dokja Cyan** (`#06B6D4`): Canonical realizations and inner monologues.
- 🔶 **Constellation Gold** (`#F59E0B`): Star Stream messages and world-changing events.
- 🔴 **Flame Crimson** (`#EF4444`): High-stakes battles and apocalyptic moments.
- 🟢 **Peace Emerald** (`#10B981`): Companion conversations and quiet interludes.
- 🟣 **Abyss Violet** (`#8B5CF6`): Hidden scenarios and cosmic mysteries.
- Attach personal notes and reflections to any quote and search them in the **Archives**.

---

## 📚 Library & Cloud Synchronization

- **Elevated 2:3 Poster Grid**: Displays your library with high-resolution extracted cover art and shelf badges (supports standard and large grid views).
- **Custom Shelves**: Organize novels into *Currently Reading*, *Completed*, and customizable shelves.
- **In-App File Explorer**: Browse storage folders (`/sdcard/Books/`, `/sdcard/Download/`, desktop directories) and import EPUBs with a single tap.
- **WebDAV Cloud Backup**: Safely backup and restore reading telemetry, bookmarks, highlights, and your Star Stream profile to Nextcloud, ownCloud, or private WebDAV storage.
- **The Epilogue Grimoire & Updates**: In-app searchable feature manual and 1-tap GitHub Releases update checker with detailed changelogs.

---

## ⚡ Performance Benchmark

- **Zero Frame Drops**: Smooth 60/120 FPS scrolling even on massive 90MB+ multi-volume EPUBs (e.g. ORV's 551 chapters).
- **Sub-200ms JIT Sliding Window**: Intelligent chapter caching and sliding-window loading eliminate parse delays on huge collections.
- **Ultra-Lean Footprint**: Release APK is optimized down to ~20MB with split-per-ABI builds as low as ~19MB.

---

## 📦 Download & Installation

Pre-compiled release packages are available on the [**GitHub Releases Page**](https://github.com/EtherealInsanity/Epilogue/releases):

### Android Packages (v2.0.4)

| APK Package | Recommended For |
| :--- | :--- |
| **`Epilogue-v2.0.4-arm64-v8a.apk`** | **99% of modern Android smartphones** (fastest, lightest) |
| **`Epilogue-v2.0.4-universal.apk`** | **All devices** (universal installer for phones, tablets, e-ink) |
| **`Epilogue-v2.0.4-armeabi-v7a.apk`** | Older 32-bit Android phones |
| **`Epilogue-v2.0.4-x86_64.apk`** | Android emulators & Chromebooks |

### Desktop Packages

| Platform | Package Format | Details |
| :--- | :--- | :--- |
| **Linux (x86_64)** | `.tar.gz` / `.zip` | Native GTK3 Desktop Bundle |
| **Windows (x64)** | `.zip` | Native Win32 Desktop Release |

---

## 💬 Community & Support

Join fellow Constellations and Incarnations in the community:

- **Discord Server**: [**Join Epilogue on Discord**](https://discord.gg/dBSRDDrNUV) — Discuss web novels, share EPUB styling tips, get help, and participate in feature development.
- **GitHub Issues**: [**Report a Bug / Request a Feature**](https://github.com/EtherealInsanity/Epilogue/issues)
- **Official Showcase**: [**etherealinsanity.github.io/Epilogue**](https://etherealinsanity.github.io/Epilogue/)

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (`>= 3.10.0`, tested on 3.47.x)
- [Android SDK](https://developer.android.com) (API Level 35 for Android builds)
- OpenJDK 17
- CMake, Ninja, and GTK3 development headers (for Linux desktop builds)
- Visual Studio 2022 with "Desktop development with C++" (for Windows desktop builds)

### Steps

```bash
# 1. Clone repository
git clone https://github.com/EtherealInsanity/Epilogue.git
cd Epilogue

# 2. Install dependencies
flutter pub get

# 3. Run analyzer & test suite
flutter analyze
flutter test

# 4. Launch on connected device or desktop
flutter run

# 5. Build multi-platform release binaries
# Android APKs (Split-per-ABI & Universal)
flutter build apk --release --split-per-abi

# Linux Desktop Bundle (GTK3 Native)
flutter build linux --release

# Windows Desktop Release (Win32 Native)
flutter build windows --release
```

---

## 🏛️ Code Architecture

```
lib/
├── config/
│   └── reader_config.dart            # Typography, layout, CSS toggle, 4th Wall & Studio state
├── models/
│   ├── book_info.dart                # Metadata, cover cache, progress & word counts
│   ├── chapter.dart                  # Chapter content, raw HTML & embedded image refs
│   ├── bookmark.dart                 # Chapter bookmarks with offset text snippets
│   ├── book_highlight.dart           # Color-coded quotes with attached notes
│   ├── book_shelf.dart               # Shelf groupings (Reading, Completed, Custom)
│   ├── daily_reading_record.dart     # Daily reading telemetry and streak history
│   ├── epub_project.dart             # Epilogue Studio project model & genre templates
│   ├── linter_issue.dart             # Studio pre-flight EPUB linter issue model
│   ├── orv_canon_item.dart           # Canonical constellation items & shop records
│   ├── orv_state.dart                # Coins, equipped modifiers, fables & attributes
│   ├── reading_session.dart          # Reading duration, timestamp & session telemetry
│   └── scenario.dart                 # 150+ canonical Main, Bounty & Hidden scenarios
├── services/
│   ├── storage_service.dart          # SharedPreferences single source of truth & migration
│   ├── epub_parser_service.dart      # High-speed EPUB unpacking, CSS extractor & memory cache
│   ├── epub_builder_service.dart     # EPUB 3.3/2 NCX packager, OPF builder & ZIP archiver
│   ├── epub_linter_service.dart      # Pre-flight XHTML, unclosed tag & metadata validator
│   ├── studio_project_service.dart   # Studio project persistence, cloning & file I/O
│   ├── orv_service.dart              # Star Stream unlock engine & catalog logic
│   ├── data_sync_service.dart        # WebDAV cloud backup & restore engine
│   ├── update_checker_service.dart   # GitHub Releases API update checker
│   ├── url_launcher_service.dart     # Safe external link and Discord launcher
│   └── file_explorer_service.dart    # Cross-platform filesystem navigation
├── screens/
│   ├── main_shell_screen.dart        # Root scaffold, navigation bar & dynamic dock
│   ├── library_screen.dart           # Whole-poster 2:3 book grid & shelf manager
│   ├── modern_reader_screen.dart     # The reader engine (Scroll + Page-Turn + CSS + Zoom)
│   ├── scenario_screen.dart          # Scenario quest log & filterable quote archives
│   ├── attribute_window_screen.dart  # Incarnation profile, stats & equipped fables
│   ├── retrocognition_screen.dart    # Worldline sync: batch progress & scenario calculation
│   ├── settings_screen.dart          # Reactive themes, UI scaling, WebDAV sync & controls
│   ├── feature_manual_screen.dart    # The Epilogue Grimoire in-app guide
│   ├── changelog_screen.dart         # Version history, release notes & update logs
│   ├── in_app_file_explorer_screen.dart # Device file explorer & single-tap EPUB import
│   ├── studio_dashboard_screen.dart  # Studio projects hub, template picker & import/export
│   ├── studio_editor_screen.dart     # Tri-mode (WYSIWYG/Markdown/Source) chapter editor
│   ├── studio_spine_screen.dart      # Drag-and-drop chapter ordering & word counts
│   ├── studio_metadata_screen.dart   # EPUB metadata, Dublin Core & cover editor
│   └── studio_linter_screen.dart     # EPUB pre-flight validation & 1-click auto-repair
├── theme/
│   └── epilogue_theme.dart           # Paper Light, Sepia Warm, Slate Gray, OLED Dark, 4th Wall
└── widgets/
    ├── bottom_sheet_book_detail.dart     # Book details, chapter list & actions
    ├── bottom_sheet_reader_settings.dart # Live reader typography & margin bottom sheet
    ├── dialog_create_highlight.dart      # Constellation quote highlight & note creator
    ├── dialog_edit_metadata.dart         # Book title, author & shelf editor
    ├── dialog_manual_reading_import.dart # Historical streak & reading telemetry importer
    ├── modern_toc_bottom_sheet.dart      # Auto-scrolling chapter Table of Contents
    ├── star_stream_badge.dart            # Constellation status & scenario badges
    └── star_stream_card.dart             # Themed cards for lore and attribute displays
```

---

## 📜 Disclaimer & Acknowledgments

- *Omniscient Reader's Viewpoint* (전지적 독자 시점) is created by **Sing Shong** (싱숑) and published by **Munpia**.
- Epilogue is a non-commercial, open-source fan creation developed out of deep admiration for the story and its readers. All thematic modifiers, fables, and scenarios are used purely as non-commercial homages to the novel.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
