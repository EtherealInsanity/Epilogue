# Project: Epilogue Reader Mode Enhancements, Epub Studio Purge, and Text Highlight Dismissal

## Architecture
Epilogue is an offline Flutter/Dart reader application with reader features, scenario tracking, and library management.
This project resolves three core requirements across four functional subsystems:
1. **Packaging & Subsystem Decoupling**: Complete purge of the isolated Epub Studio subsystem (10 Dart files, 1 test file, 1 asset) and decoupling of all integration points in `MainShellScreen`, `BottomSheetBookDetail`, `ReaderConfig`, and `SettingsScreen`.
2. **EPUB Parser & Asset Pipeline**: Overhaul of `EpubParserService` and `Chapter` model to comprehensively extract images (including WebP, SVG, and unmanifested archive assets), maintain a resilient persistent image index (`.index.json`), and provide URI-decoded, chapter-relative path resolution.
3. **Reader Canvas & Gestures**: Enhancement of `ModernReaderScreen` to render images reliably across rich HTML (`flutter_html`) and clean text modes, while fixing touch gesture handling to immediately dismiss the text highlight toolbar upon tapping outside or deselecting text.
4. **E2E & Verification Track**: Dual-track automated test suite covering all four test tiers (feature coverage, edge/corner cases, pairwise combinations, real-world workloads) to guarantee zero regressions and 100% acceptance compliance.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Studio Subsystem File Purge | Delete all 10 studio screens/services/models, 1 test file, and 1 asset file | M1 | Survey R2 |
| F2 | Studio Navigation & Route Purge | Remove studio imports, tab in `MainShellScreen`, and "EDIT IN STUDIO" button in `BottomSheetBookDetail` | M1 | Survey R2 |
| F3 | Studio Config & Settings Cleanup | Remove `enableEpubStudio` from `ReaderConfig` and switch from `SettingsScreen` | M1 | Survey R2 |
| F4 | Orphaned Archive Dependency Removal | Remove `archive: ^3.6.1` from `pubspec.yaml` (orphaned after studio purge) | M1 | Survey R2 |
| F5 | Comprehensive Asset Extractor & Index | Scan `Content?.Images`, `Content?.AllFiles`, and ZIP entries for JPG/PNG/WebP/SVG/GIF; build persistent `.index.json` | M2 | Survey R1 |
| F6 | Chapter Directory Path Retention | Add `contentFileName` to `Chapter` model for RFC 3986 relative path resolution | M2 | Survey R1 |
| F7 | Robust Path Resolution Engine | Resolve relative paths, decode URL encoding, strip fragments/queries, and fallback to basenames | M2 | Survey R1 |
| F8 | Reader HTML & SVG/Base64 Rendering | Support `<img>`, `<image>`, `<svg>`, and Base64 in `ModernReaderScreen` TagExtension with error guards | M2 | Survey R1 |
| F9 | Clean Text Mode Inline Images | Preserve `[EPILOGUE_IMG:...]` markers in plain text and guard carousel to page 0 | M2 | Survey R1 |
| F10 | Tap-Outside Selection Dismissal | Intercept tap in `GestureDetector.onTapUp` to dismiss selection & toolbar when active | M3 | Survey R3 |
| F11 | Guarded Toolbar Generation | Return `SizedBox.shrink()` in `contextMenuBuilder` when selection is empty | M3 | Survey R3 |
| F12 | Selection Lifecycle Cleanup | Dismiss toolbar in `onSelectionChanged` and clear selection on page/chapter navigation | M3 | Survey R3 |
| F13 | E2E Test Suite (Tiers 1–4) | Requirement-driven opaque-box test suite for R1, R2, and R3 producing `TEST_READY.md` | E2E | Survey R1/R2/R3 |
| F14 | 100% E2E Pass & Adversarial Hardening | Pass all E2E tests + Tier 5 adversarial stress testing | M4 | Final Milestone |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Complete Removal of Epub Studio | Delete 11 studio files, decouple routes, clean config & settings, remove orphaned dependency | none | PLANNED |
| M2 | Reader Mode Image Loading Pipeline | Implement comprehensive asset extraction, chapter href retention, path resolver, and reader rendering | none | PLANNED |
| M3 | Text Highlight Bar Dismissal | Implement tap-outside dismissal, toolbar guards, and selection lifecycle cleanup | M2 | PLANNED |
| E2E | E2E Testing Track | Design and implement automated test suite across Tiers 1–4, publish `TEST_READY.md` | none | PLANNED |
| M4 | Final Acceptance & Adversarial Hardening | Pass 100% of E2E tests (Phase 1) and execute Tier 5 adversarial hardening (Phase 2) | M1, M2, M3, E2E | PLANNED |

---

## Interface Contracts

### 1. Chapter Model ↔ Reader Engine
```dart
class Chapter {
  final int index;
  final String title;
  final String plainTextContent;
  final String htmlContent;
  final int wordCount;
  final List<String> imageSrcs;
  final bool isLoaded;
  final String? contentFileName; // Added: relative path inside EPUB (e.g., "OEBPS/Text/ch01.xhtml")
}
```

### 2. EpubParserService ↔ ModernReaderScreen
```dart
class EpubParserService {
  static Future<Map<String, String>> extractAllBookImages(String filePath);
  
  static String? resolveImagePath({
    required Map<String, String> imageIndex,
    required String src,
    String? chapterHref,
  });
}
```

### 3. SelectionArea ↔ ModernReaderScreen Gestures
```dart
// Global key to control selection imperatively:
final GlobalKey<SelectionAreaState> _selectionAreaKey = GlobalKey<SelectionAreaState>();

// Clear selection and hide toolbar:
void _dismissSelectionIfActive() {
  if (_selectedTextContent.isNotEmpty) {
    _selectedTextContent = '';
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
    _selectionAreaKey.currentState?.selectableRegion.hideToolbar();
  }
}
```

---

## Code Layout & Write Ownership

| Milestone | Owned Files (Exclusive Write Access) |
|-----------|-------------------------------------|
| **M1 (Studio Purge)** | Deletions: `lib/screens/studio_*.dart` (5 files), `lib/services/studio_project_service.dart`, `lib/services/epub_builder_service.dart`, `lib/services/epub_linter_service.dart`, `lib/models/epub_project.dart`, `lib/models/linter_issue.dart`, `test/epub_studio_test.dart`, `assets/images/icon_studio.png`.<br>Modifications: `lib/screens/main_shell_screen.dart`, `lib/widgets/bottom_sheet_book_detail.dart`, `lib/config/reader_config.dart`, `lib/screens/settings_screen.dart`, `lib/screens/feature_manual_screen.dart`, `test/storage_service_test.dart`, `pubspec.yaml`. |
| **M2 (Image Loading)** | `lib/services/epub_parser_service.dart`, `lib/models/chapter.dart`, `lib/screens/modern_reader_screen.dart` (Image rendering, TagExtension, carousel, plain text tokens). |
| **M3 (Highlight Dismissal)** | `lib/screens/modern_reader_screen.dart` (SelectionArea, GestureDetector onTapUp, contextMenuBuilder, onSelectionChanged, navigation reset). Runs sequentially after M2. |
| **E2E Track** | `test/e2e/`, `test/e2e_reader_images_test.dart`, `test/e2e_studio_removal_test.dart`, `test/e2e_highlight_dismissal_test.dart`, `TEST_INFRA.md`, `TEST_READY.md`. |
| **M4 (Final Milestone)** | Bug fixes across affected files to achieve 100% pass on E2E test suite + Tier 5 tests. |
