# Epilogue Test Infrastructure & E2E Verification Methodology

## 1. Overview
The Epilogue test infrastructure provides automated, multi-tiered regression testing and requirement-driven opaque-box verification for the Epilogue EPUB reader application.
The verification framework specifically validates three core requirements:
- **Requirement R1**: Reader Mode Image Loading across diverse EPUB formats, structures, encodings, and container tags.
- **Requirement R2**: Complete Removal of Epub Studio across all disk files, imports, routes, configuration toggles, and UI components.
- **Requirement R3**: Immediate Dismissal of the Text Highlighting Toolbar upon tap-outside, programmatic selection clear, or page/chapter navigation.

---

## 2. Test Runner & Execution Environment
- **Framework**: Flutter Test (`package:flutter_test`)
- **Execution Command**:
  ```bash
  flutter test
  ```
- **Targeted E2E Suites**:
  ```bash
  # Studio Removal E2E suite
  flutter test test/e2e_studio_removal_test.dart

  # Reader Image Loading E2E suite
  flutter test test/e2e_reader_images_test.dart

  # Text Selection & Highlight Dismissal E2E suite
  flutter test test/e2e_highlight_dismissal_test.dart
  ```
- **Analyzer Command**:
  ```bash
  flutter analyze --no-fatal-infos
  ```

---

## 3. Four-Tier Testing Methodology & Tier Thresholds

The E2E test suite adheres to a structured 4-tier verification model:

```
┌──────────────────────────────────────────────────────────┐
│ Tier 4: Real-World Workloads & Full Widget Lifecycle     │
│  - MainShellScreen 4-tab rendering                       │
│  - SettingsScreen & ReaderConfig studio toggle absence   │
│  - ModernReaderScreen Image widget rendering & no crash  │
│  - Chapter/Page transitions clearing dangling selection  │
├──────────────────────────────────────────────────────────┤
│ Tier 3: Pairwise Combinatorial & Resolver Matrices       │
│  - Path resolver canonical / relative / case / basename  │
│  - Zero studio imports across all lib/ and test/ files   │
│  - Programmatic selection clear without HUD / page shift │
├──────────────────────────────────────────────────────────┤
│ Tier 2: Boundary Value Analysis & Complex Formats        │
│  - Relative paths (../Images/), percent-encoded (%20)    │
│  - WebP formats, unmanifested zip entries, Base64 URIs   │
│  - SVG container tags (<svg><image .../>)                │
│  - Tap outside selected text immediate dismissal        │
├──────────────────────────────────────────────────────────┤
│ Tier 1: Category-Partition & Primary Happy Paths         │
│  - Standard EPUB image archive extraction                │
│  - 11 studio files non-existence check on disk           │
│  - Long press on text displaying '★ Highlight / Note'    │
└──────────────────────────────────────────────────────────┘
```

### Tier 1: Category-Partition & Primary Happy Paths
- **Threshold**: 100% pass on standard execution paths.
- **Scope**:
  - Verification that standard EPUB image extraction succeeds and caches properly.
  - Verification that all 11 studio files and studio asset files are completely purged from disk.
  - Verification that long-pressing reader text surfaces the highlight toolbar containing `★ Highlight / Note`.

### Tier 2: Boundary Value Analysis & Complex Formats
- **Threshold**: Zero unhandled exceptions (`ImageCodecException`, `RangeError`, `NoSuchMethodError`); 100% graceful handling.
- **Scope**:
  - Image paths traversing parent directories (`../Images/`, `../../media/`).
  - Filenames containing percent-encoded spaces (`%20`) and URI symbols.
  - Modern compression formats (`image/webp`) and legacy aliases (`image/jpg`).
  - Unmanifested image entries residing in EPUB ZIP archives outside OPF `<manifest>`.
  - Base64 data URIs (`data:image/png;base64,...`).
  - SVG wrappers with `<svg><image xlink:href="..."/></svg>`.
  - Tap-outside gestures immediately dismissing the highlight bar without unwanted side-effects.

### Tier 3: Pairwise Combinatorial & Resolver Matrices
- **Threshold**: Deterministic path matching across all canonical, relative, case-insensitive, and basename combinations. Zero residual references in code.
- **Scope**:
  - Image resolver combinatorial matrix:
    - Path depth (0, 1, 2 levels) × Filename case (exact, mismatched) × URI encoding (raw, encoded) × Archive structure.
  - Grep matrix across every `.dart` file in `lib/` and `test/` verifying 0 studio references.
  - Programmatic selection clear verifying that `hideToolbar()` and `clearSelection()` run without triggering page turn or toggling reader HUD.

### Tier 4: Real-World Workloads & Full Widget Lifecycle
- **Threshold**: Complete end-to-end user experience fidelity with zero UI regressions.
- **Scope**:
  - `MainShellScreen` renders exactly 4 navigation destinations (Archive, Scenarios, Status, Settings) and 0 Studio destinations.
  - `SettingsScreen` and `ReaderConfig` contain no studio switch or serialization field.
  - `ModernReaderScreen` instantiates valid `Image.file` and `Image.memory` widgets for embedded images without red-screen crashes.
  - Reader navigation across pages and chapters cleans up active selection state.

---

## 4. Feature Inventory Coverage Mapping

| Feature ID | Feature Name | Test File | Primary Tier | Verification Method |
|------------|--------------|-----------|--------------|---------------------|
| **F1** | Studio Subsystem File Purge | `test/e2e_studio_removal_test.dart` | Tier 1 | Verify 11 studio files + asset file do not exist on disk |
| **F2** | Studio Navigation & Route Purge | `test/e2e_studio_removal_test.dart` | Tier 2 & 3 | Scan `lib/` and `test/` for studio imports; pump `MainShellScreen` |
| **F3** | Studio Config & Settings Cleanup | `test/e2e_studio_removal_test.dart` | Tier 4 | Verify `ReaderConfig` serialization & `SettingsScreen` widget tree |
| **F4** | Orphaned Archive Dependency Removal | `test/e2e_studio_removal_test.dart` | Tier 2 | Verify `package:archive` is not imported across `lib/` |
| **F5** | Comprehensive Asset Extractor & Index | `test/e2e_reader_images_test.dart` | Tier 1 & 2 | Extract EPUB containing JPG, PNG, WebP, SVG, and unmanifested files |
| **F6** | Chapter Directory Path Retention | `test/e2e_reader_images_test.dart` | Tier 3 | Check `Chapter.contentFileName` retention and relative path resolution |
| **F7** | Robust Path Resolution Engine | `test/e2e_reader_images_test.dart` | Tier 3 | Unit tests for canonical, relative, URL-decoded, and basename lookup |
| **F8** | Reader HTML & SVG/Base64 Rendering | `test/e2e_reader_images_test.dart` | Tier 4 | Widget test `ModernReaderScreen` with `<img>`, `<svg><image>`, and Base64 |
| **F9** | Clean Text Mode Inline Images | `test/e2e_reader_images_test.dart` | Tier 4 | Verify plain text inline image markers render without carousel duplication |
| **F10** | Tap-Outside Selection Dismissal | `test/e2e_highlight_dismissal_test.dart` | Tier 2 | Tap outside active selection; assert toolbar dismisses immediately |
| **F11** | Guarded Toolbar Generation | `test/e2e_highlight_dismissal_test.dart` | Tier 1 | Assert `★ Highlight / Note` only appears when text is actively selected |
| **F12** | Selection Lifecycle Cleanup | `test/e2e_highlight_dismissal_test.dart` | Tier 3 & 4 | Assert programmatic clear and page navigation clear selection & toolbar |
| **F13** | E2E Test Suite (Tiers 1–4) | All 3 E2E test files | Tiers 1–4 | Publish `TEST_INFRA.md` and `TEST_READY.md` |
| **F14** | 100% E2E Pass & Hardening | Final verification | All Tiers | Full test suite clean run |

---

## 5. Test Suite Specifications

### 5.1 `test/e2e_studio_removal_test.dart`
- **File System Verification**:
  - `lib/screens/studio_dashboard_screen.dart`
  - `lib/screens/studio_editor_screen.dart`
  - `lib/screens/studio_linter_screen.dart`
  - `lib/screens/studio_metadata_screen.dart`
  - `lib/screens/studio_spine_screen.dart`
  - `lib/services/studio_project_service.dart`
  - `lib/services/epub_builder_service.dart`
  - `lib/services/epub_linter_service.dart`
  - `lib/models/epub_project.dart`
  - `lib/models/linter_issue.dart`
  - `test/epub_studio_test.dart`
  - `assets/images/icon_studio.png`
- **Static Analysis & Import Scanning**:
  - Search all `.dart` files in `lib/` and `test/` for regex:
    `import\s+['"][^'"]*studio[^'"]*['"]`
    `import\s+['"][^'"]*epub_builder[^'"]*['"]`
    `import\s+['"][^'"]*epub_linter[^'"]*['"]`
    `import\s+['"][^'"]*epub_project[^'"]*['"]`
    `import\s+['"][^'"]*package:archive/archive.dart['"]`
- **UI Navigation & Routes**:
  - Pump `MainShellScreen`: exactly 4 `NavigationDestination` items; zero with label 'Studio'.
  - Inspect `BottomSheetBookDetail`: zero 'EDIT IN STUDIO' buttons.
- **Configuration & Settings**:
  - `ReaderConfig().toJson()` must not have key `'enableEpubStudio'`.
  - Pump `SettingsScreen`: zero 'Enable Epilogue Studio' switch tiles.

### 5.2 `test/e2e_reader_images_test.dart`
- **Tier 1 (Happy Path)**:
  - Generate standard EPUB archive with `OEBPS/images/cover.jpg` and `OEBPS/images/fig1.png`.
  - Verify `extractAllBookImages` extracts files to disk and returns indexed mapping.
- **Tier 2 (Boundary Cases)**:
  - Relative paths: `../Images/art.png` from `OEBPS/Text/ch1.xhtml`.
  - URL-encoded paths: `Figure%201.jpg` mapping to `Figure 1.jpg`.
  - Modern formats: `image/webp` file extracted from archive.
  - Unmanifested archive assets: Image entry present in zip archive but missing in OPF manifest.
  - Base64 data URIs: `data:image/png;base64,iVBORw...` rendered with `Image.memory`.
  - SVG wrappers: `<svg><image xlink:href="..."/>` and `<image href="..."/>`.
  - Missing assets: Graceful resolution returning null / empty placeholder without throwing unhandled exceptions.
- **Tier 3 (Combinatorial Path Resolver)**:
  - Matrix testing `EpubParserService.resolveImagePath`:
    - Canonical full path: `OEBPS/images/fig1.png`
    - Relative path with `chapterHref`: `../images/fig1.png` with `OEBPS/Text/ch01.xhtml`
    - URL-encoded source: `fig%201.png`
    - Queries & fragments: `fig1.png#page=1?v=2`
    - Basename fallback: `fig1.png`
    - Case-insensitive fallback: `FIG1.PNG` -> `fig1.png`
- **Tier 4 (Reader Widget Rendering)**:
  - Pump `ModernReaderScreen` containing image references in HTML.
  - Verify `Image.file` and `Image.memory` widgets exist in the tree.
  - Verify error guards prevent `ImageCodecException` on invalid or standalone vector assets.

### 5.3 `test/e2e_highlight_dismissal_test.dart`
- **Tier 1 (Happy Path Toolbar Display)**:
  - Long press on reading canvas text paragraph.
  - Verify toolbar appears and contains `★ Highlight / Note`.
- **Tier 2 (Tap-Outside Dismissal)**:
  - Tap on coordinates outside the text selection while toolbar is active.
  - Verify toolbar and selection handles immediately disappear (`findsNothing`).
  - Verify the dismissal tap does NOT turn the page or toggle the reader HUD.
- **Tier 3 (Programmatic Clear & Toolbar Guard)**:
  - Programmatic selection collapse: assert toolbar is dismissed.
  - Verify `contextMenuBuilder` returns `SizedBox.shrink()` when selection text is empty.
- **Tier 4 (Navigation Lifecycle Cleanup)**:
  - When user navigates to next/previous page or switches chapters with an active selection, verify the dangling selection is cleared and toolbar is hidden.
