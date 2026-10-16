# 🌌 Epilogue (독자의 에필로그)

<p align="center">
  <img src="assets/images/orvlogo.png" alt="Epilogue Logo" width="140" />
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

---

> *"There are three ways to survive in a ruined world. Now, I have forgotten a few. But one thing is certain: you who are reading this will survive."*  
> — **Omniscient Reader's Viewpoint**

**Epilogue** (`com.epilogue.read`) is an open-source, distraction-free reading application built specifically for long-running web novels, light novels, and epic fiction (such as *Omniscient Reader's Viewpoint*, *Lord of the Mysteries*, and *Shadow Slave*). It combines an elegant typography engine with seamless *Star Stream* telemetry and progression.

---

## ✨ Key Features

### 📖 The Sacred Reading Experience
- **Distraction-Free Typography**: Pure paper aesthetic (`#FFFFFF` background with `#111827` deep ink text), customizable serif / sans-serif fonts, adjustable line height, and margin controls.
- **Dynamic Viewport Budgeting**: Automatically calculates live character and line capacities via `LayoutBuilder`, completely eliminating the empty bottom gap on modern tall aspect-ratio displays (20:9 / 21:9).
- **Dual Reading Modes**:
  - **Continuous Scroll**: Smooth scrolling with reading position tracking.
  - **Page-Turn View**: Clean pagination breaking at natural paragraph and sentence boundaries without tearing HTML tags in half.
- **Original Book Formatting (EPUB CSS Engine)**:
  - Extracts embedded stylesheets and `<style>` blocks on-the-fly.
  - Renders headers (`<h1>`–`<h6>`), blockquotes, dividers, and alignments faithful to the original publication.
- **Inline Image Pinch-to-Zoom**: Interactive viewer supporting 0.8x to 4.0x zoom on embedded illustrations and character charts.

### 🌌 The Star Stream Progression
Epilogue gamifies your real-world reading habits subtly and authentically:
- **234 Constellation Modifiers**: Unlock modifiers based on reading milestones.
- **45 Canonical Fables**: Acquired as you complete major volumes and word-count goals.
- **28 Incarnation Attributes**: Reflecting your reading endurance, focus, and speed.
- **150+ Canonical Scenarios**: Main, Bounty, and Hidden scenarios that clear naturally as chapters are read.
- **Reading Telemetry**: Real-time Words Per Minute (WPM) tracking, total reading time, daily streaks, and volume completion stats.

### 🖍️ Archives & Annotations
- **5 Star Stream Highlighting Palettes**:
  - 🔷 Dokja Cyan (`#06B6D4`)
  - 🔶 Constellation Gold (`#F59E0B`)
  - 🔴 Flame Crimson (`#EF4444`)
  - 🟢 Peace Emerald (`#10B981`)
  - 🟣 Abyss Violet (`#8B5CF6`)
- **Note Attachment**: Attach personal thoughts, commentary, and theories to highlighted passages.
- **Filterable Archives**: Search and filter highlights by novel, chapter, or color palette.

### ⚡ Performance & In-Memory Caching
- **Fast Parsing**: Custom parsing and caching pipelines capable of opening massive 90MB+ multi-volume EPUBs (e.g., ORV's 551 chapters) with zero lag or frame drops.
- **Local-First & Private**: Completely offline-capable with zero external tracking.
- **OPDS & WebDAV Sync**: Connect to your Calibre library or personal cloud for remote library imports and backups.

---

## 🏛️ Codebase Architecture

```
lib/
├── config/
│   └── reader_config.dart          # Reader settings (theme, font, margins, CSS toggle, UI scale)
├── models/
│   ├── book_info.dart              # Book metadata, cover image path, total chapters, progress
│   ├── chapter.dart                # Chapter entity (plain text, HTML content, image srcs)
│   ├── bookmark.dart               # Chapter bookmarks with offset snippets
│   ├── book_highlight.dart         # Color-coded text highlights & user notes
│   ├── book_shelf.dart             # Custom shelves (Reading, Completed, Plan to Read)
│   ├── orv_state.dart              # Star Stream progression state (coins, fables, modifiers)
│   └── scenario.dart               # 150+ canonical scenarios across Main, Bounty & Hidden tiers
├── services/
│   ├── storage_service.dart        # SharedPreferences-backed single source of truth
│   ├── epub_parser_service.dart    # High-speed EPUB unpacking, CSS extractor & in-memory cache
│   ├── orv_service.dart            # Star Stream unlock logic & progression catalog
│   ├── opds_service.dart           # OPDS catalog browsing & download manager
│   └── data_sync_service.dart      # WebDAV cloud backup & restore service
├── screens/
│   ├── main_shell_screen.dart      # Dynamic navigation dock & global TextScaler root
│   ├── library_screen.dart         # Whole-poster 2:3 book grid, shelves & EPUB importer
│   ├── modern_reader_screen.dart   # Continuous scroll & page-turn engine
│   ├── scenario_screen.dart        # Scenarios quest log & color-filtered quote archives
│   ├── attribute_window_screen.dart# Incarnation profile & lifetime reading telemetry
│   └── settings_screen.dart        # Customization, UI scaling, themes & storage options
├── widgets/
│   ├── bottom_sheet_reader_settings.dart # In-reader typography & layout settings
│   ├── dialog_create_highlight.dart      # Highlight color selector & note attachment
│   ├── dialog_manual_reading_import.dart # Past stats migration dialog
│   └── modern_toc_bottom_sheet.dart      # Table of Contents with live progress markers
└── theme/
    └── epilogue_theme.dart         # Visual identity (Deep Space Dark, Paper Light, Dokja Cyan)
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.10.0`, tested on Flutter 3.47.x / Dart 3.13.x)
- [Android SDK](https://developer.android.com/studio) (API 35 compile target)
- Java OpenJDK 17

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DistantPromise/Epilogue.git
   cd Epilogue
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify analyzer and test suite:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch on a connected device:**
   ```bash
   flutter run
   ```

### Building Release APKs

To generate lean, architecture-optimized APKs (~8.8 MB per ABI):
```bash
flutter build apk --release --split-per-abi
```
The output APKs will be located at:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

---

## 📜 Disclaimer & Acknowledgments

- *Omniscient Reader's Viewpoint* (전지적 독자 시점) is the creative work of authors **Sing Shong** (싱숑) and published by **Munpia**.
- Epilogue is a non-commercial, open-source fan project created out of deep admiration for the story and its readers. All in-game lore, modifiers, and fables are used purely as thematic homages.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
