# 🌌 Epilogue (독자의 에필로그)

<p align="center">
  <img src="assets/images/orvlogo.png" alt="Epilogue Logo" width="160" />
</p>

<p align="center">
  <strong>An immersive, high-performance EPUB & Web Novel reading companion for Android with Star Stream progression.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20(API%2021%2B)-brightgreen.svg" alt="Platform" />
  <img src="https://img.shields.io/badge/Flutter-%3E%3D3.10.0-02569B.svg?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2.svg?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Tests-19%2F19%20Passing-success.svg" alt="Tests" />
  <img src="https://img.shields.io/badge/Analyzer-0%20Issues-brightgreen.svg" alt="Analyzer" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" />
</p>

<p align="center">
  <a href="https://distantpromise.github.io/Epilogue/"><strong>🌐 Official Website & Live Interactive Demo</strong></a> • 
  <a href="https://github.com/DistantPromise/Epilogue/releases"><strong>📦 Download APKs</strong></a> • 
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

**Epilogue** (`com.epilogue.read`) is an open-source, distraction-free reading application built specifically for 500+ chapter epics, light novels, and long-running web fiction (such as *Omniscient Reader's Viewpoint*, *Lord of the Mysteries*, and *Shadow Slave*). 

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
- **True OLED Pitch-Black**: A true black background option for night-time reading that saves battery and eliminates eye strain.

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

### 🔄 Dual Reading Modes
- **Continuous Scroll Mode**: Granular scroll position tracking with seamless chapter boundaries.
- **Dynamic Page-Turn Mode**: Tactile page navigation with left/right tap zones and in-depth reading progress.

### 📺 Retro CRT Scanline Shader
- Includes a custom GLSL fragment shader (`shaders/crt.frag`) that adds an optional vintage CRT scanline overlay, giving your text a cyberpunk, retro-terminal ambiance.

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

- **Elevated 2:3 Poster Grid**: Displays your library with high-resolution extracted cover art and shelf badges.
- **Custom Shelves**: Organize novels into *Currently Reading*, *Completed*, and customizable shelves.
- **In-App File Explorer**: Browse storage folders (`/sdcard/Books/`, `/sdcard/Download/`) and import EPUBs with a single tap.
- **OPDS Catalog Browser**: Connect directly to Calibre libraries, Standard Ebooks, and remote OPDS servers over Wi-Fi.
- **WebDAV Cloud Backup**: Safely backup and restore reading telemetry, bookmarks, highlights, and your Star Stream profile to Nextcloud or private WebDAV storage.

---

## ⚡ Performance Benchmark

- **Zero Frame Drops**: Smooth 60/120 FPS scrolling even on massive 90MB+ multi-volume EPUBs (e.g. ORV's 551 chapters).
- **In-Memory Caching**: Intelligent chapter metadata and image caching pipeline ensures chapter flips take less than 16 milliseconds.
- **Ultra-Lean Footprint**: Release APK is optimized down to ~20MB with split-per-ABI builds as low as ~8.8MB.

---

## 📦 Download & Installation

Pre-compiled release APKs are available on the [**GitHub Releases Page**](https://github.com/DistantPromise/Epilogue/releases):

| APK Package | Recommended For |
| :--- | :--- |
| **`Epilogue-v1.0.0-arm64-v8a.apk`** | **99% of modern Android smartphones** (fastest, lightest) |
| **`Epilogue-v1.0.0-universal.apk`** | **All devices** (universal installer for phones, tablets, e-ink) |
| **`Epilogue-v1.0.0-armeabi-v7a.apk`** | Older 32-bit Android phones |
| **`Epilogue-v1.0.0-x86_64.apk`** | Android emulators & Chromebooks |

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (`>= 3.10.0`, tested on 3.47.x)
- [Android SDK](https://developer.android.com) (API Level 35)
- OpenJDK 17

### Steps

```bash
# 1. Clone repository
git clone https://github.com/DistantPromise/Epilogue.git
cd Epilogue

# 2. Install dependencies
flutter pub get

# 3. Run analyzer & test suite
flutter analyze
flutter test

# 4. Launch on connected device
flutter run

# 5. Build release APK
flutter build apk --release --split-per-abi
```

---

## 🏛️ Code Architecture

```
lib/
├── config/
│   └── reader_config.dart          # Typography, layout, CSS toggle & UI scale state
├── models/
│   ├── book_info.dart              # Metadata, cover cache, progress & word counts
│   ├── chapter.dart                # Chapter content, raw HTML & embedded image refs
│   ├── bookmark.dart               # Chapter bookmarks with offset text snippets
│   ├── book_highlight.dart         # Color-coded quotes with attached notes
│   ├── book_shelf.dart             # Shelf groupings (Reading, Completed, Custom)
│   ├── orv_state.dart              # Coins, equipped modifiers, fables & attributes
│   └── scenario.dart               # 150+ canonical Main, Bounty & Hidden scenarios
├── services/
│   ├── storage_service.dart        # SharedPreferences single source of truth & migration
│   ├── epub_parser_service.dart    # High-speed EPUB unpacking, CSS extractor & memory cache
│   ├── orv_service.dart            # Star Stream unlock engine & catalog logic
│   ├── opds_service.dart           # OPDS catalog browser & network downloader
│   └── data_sync_service.dart      # WebDAV cloud backup & restore engine
├── screens/
│   ├── main_shell_screen.dart      # Root scaffold, navigation bar & dynamic dock
│   ├── library_screen.dart         # Whole-poster 2:3 book grid & shelf manager
│   ├── modern_reader_screen.dart   # The reader engine (Scroll + Page-Turn + CSS + Zoom)
│   ├── scenario_screen.dart        # Scenario quest log & filterable quote archives
│   ├── attribute_window_screen.dart# Incarnation profile, stats & equipped fables
│   ├── retrocognition_screen.dart  # Worldline sync: batch progress & scenario calculation
│   ├── opds_browser_screen.dart    # Calibre / OPDS remote library explorer
│   └── settings_screen.dart        # Themes, UI scaling, WebDAV sync & storage controls
└── theme/
    └── epilogue_theme.dart         # Frost paper light, pitch dark, Dokja cyan, star gold
```

---

## 📜 Disclaimer & Acknowledgments

- *Omniscient Reader's Viewpoint* (전지적 독자 시점) is created by **Sing Shong** (싱숑) and published by **Munpia**.
- Epilogue is a non-commercial, open-source fan creation developed out of deep admiration for the story and its readers. All thematic modifiers, fables, and scenarios are used purely as non-commercial homages to the novel.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
