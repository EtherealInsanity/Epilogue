import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import '../config/reader_config.dart';
import '../models/book_info.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';
import '../models/reading_session.dart';
import '../services/storage_service.dart';
import '../services/epub_parser_service.dart';
import '../services/orv_service.dart';
import '../theme/epilogue_theme.dart';
import '../widgets/modern_toc_bottom_sheet.dart';
import '../widgets/bottom_sheet_reader_settings.dart';
import '../widgets/dialog_create_highlight.dart';

class ModernReaderScreen extends StatefulWidget {
  final BookInfo book;
  final List<Chapter> chapters;
  final int initialChapterIndex;
  final ReaderConfig config;
  final StorageService storageService;

  const ModernReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    required this.initialChapterIndex,
    required this.config,
    required this.storageService,
  });

  @override
  State<ModernReaderScreen> createState() => _ModernReaderScreenState();
}

class _ModernReaderScreenState extends State<ModernReaderScreen> with WidgetsBindingObserver {
  late ReaderConfig _config;
  late int _currentChapterIndex;
  bool _hudVisible = false;
  bool _fourthWallActive = false;

  // Reading time & activity tracking
  static const int _idleTimeoutSeconds = 120;
  DateTime _lastInteractionTime = DateTime.now();
  int _activeSeconds = 0;
  int _activeWords = 0;
  Timer? _activityTicker;

  // Live Star Stream Constellation Reaction
  ConstellationEvent? _activeConstellationEvent;
  Timer? _constellationDismissTimer;

  // Page & scroll controllers
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  List<String> _pageChunks = [];
  int _currentPageIndex = 0;
  Size? _lastMeasuredSize;
  bool _initialPositionRestored = false;

  // Book images cache map: normalized name/src -> absolute file path on disk
  final Map<String, String> _bookImageFiles = {};
  String _bookCss = '';
  String _selectedTextContent = '';
  SelectableRegionState? _selectableRegionState; // saved from contextMenuBuilder

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _config = widget.config;
    _currentChapterIndex = widget.initialChapterIndex.clamp(0, widget.chapters.length - 1);
    _fourthWallActive = widget.config.fourthWallActive;
    _lastScrollOffset = (widget.book.lastReadChapterIndex == widget.initialChapterIndex)
        ? widget.book.lastReadScrollOffset
        : 0.0;
    _currentPageIndex = (widget.book.lastReadChapterIndex == widget.initialChapterIndex)
        ? widget.book.lastReadPageIndex
        : 0;
    _pageController = PageController();
    _scrollController.addListener(_onContinuousScroll);

    _loadBookImages();

    _activityTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final idle = DateTime.now().difference(_lastInteractionTime).inSeconds;
      if (idle < _idleTimeoutSeconds) {
        _activeSeconds++;
        if (_activeSeconds > 0 && _activeSeconds % 600 == 0) {
          _triggerConstellationReaction();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _updateProgress();
    }
  }

  void _triggerConstellationReaction() {
    final orv = OrvService(widget.storageService);
    final event = orv.getRandomConstellationReaction();
    orv.creditSponsoredCoins(event.coinsSponsored);

    if (mounted) {
      setState(() {
        _activeConstellationEvent = event;
      });
      _constellationDismissTimer?.cancel();
      _constellationDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _activeConstellationEvent = null);
      });
    }
  }

  double _lastScrollOffset = 0.0;
  double _lastRecordedOffset = 0.0;
  void _onContinuousScroll() {
    _recordInteraction();
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    _lastScrollOffset = currentOffset;
    final delta = (currentOffset - _lastRecordedOffset).abs();
    if (delta > 200) {
      _lastRecordedOffset = currentOffset;
      _activeWords += 50;
      _updateProgress();
    }
  }

  Future<void> _loadBookImages() async {
    try {
      final results = await Future.wait([
        EpubParserService.extractAllBookCss(widget.book.filePath),
        EpubParserService.extractAllBookImages(widget.book.filePath),
      ]);
      if (mounted) {
        setState(() {
          _bookCss = results[0] as String;
          _bookImageFiles.addAll(results[1] as Map<String, String>);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activityTicker?.cancel();
    _constellationDismissTimer?.cancel();
    _commitSession();
    _updateProgress();
    _scrollController.removeListener(_onContinuousScroll);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _recordInteraction() {
    _lastInteractionTime = DateTime.now();
    if (_config.hapticFeedback) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  void _commitSession() {
    if (_activeSeconds > 0 || _activeWords > 0) {
      widget.storageService.addReadingSessionTime(
        bookId: widget.book.id,
        seconds: _activeSeconds,
        wordsRead: _activeWords,
      );
      final wpm = _activeSeconds > 10 ? ((_activeWords / (_activeSeconds / 60.0)).round()).clamp(50, 999) : 220;
      widget.storageService.saveReadingSession(
        ReadingSession(
          id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          bookId: widget.book.id,
          bookTitle: widget.book.title,
          startTimeMillis: DateTime.now().millisecondsSinceEpoch - (_activeSeconds * 1000),
          endTimeMillis: DateTime.now().millisecondsSinceEpoch,
          durationSeconds: _activeSeconds,
          wordsRead: _activeWords,
          calculatedWpm: wpm,
        ),
      );
      _activeSeconds = 0;
      _activeWords = 0;
    }
  }

  Chapter get _currentChapter => widget.chapters[_currentChapterIndex];

  void _prepareChapter(Size viewportSize) {
    _lastMeasuredSize = viewportSize;
    if (_config.pageAnimation != PageAnimationType.continuousScroll) {
      if (_config.useOriginalBookStyles) {
        _splitHtmlIntoPages(viewportSize);
      } else {
        _splitTextIntoPages(viewportSize);
      }
    }
    _restoreInitialPositionIfNeeded();
  }

  void _restoreInitialPositionIfNeeded() {
    if (_initialPositionRestored || _currentChapterIndex != widget.initialChapterIndex) return;
    _initialPositionRestored = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_config.pageAnimation == PageAnimationType.continuousScroll) {
        if (_scrollController.hasClients && widget.book.lastReadScrollOffset > 0) {
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(widget.book.lastReadScrollOffset.clamp(0.0, max > 0 ? max : widget.book.lastReadScrollOffset));
        }
      } else {
        if (_pageController.hasClients && widget.book.lastReadPageIndex > 0 && _pageChunks.isNotEmpty) {
          final target = widget.book.lastReadPageIndex.clamp(0, _pageChunks.length - 1);
          _pageController.jumpToPage(target);
        }
      }
    });
  }

  void _splitHtmlIntoPages(Size size) {
    final html = _currentChapter.htmlContent;
    if (html.isEmpty) {
      _pageChunks = ['<p>[This chapter contains no text content]</p>'];
      return;
    }

    final double margin = _config.horizontalMargin > 0 ? _config.horizontalMargin : 20.0;
    final double usableHeight = (size.height - 120.0).clamp(300.0, 2400.0);
    final double usableWidth = (size.width - (margin * 2)).clamp(200.0, 1600.0);

    final double lineHeight = _config.fontSize * _config.lineSpacing;
    final int linesPerPage = (usableHeight / lineHeight).floor().clamp(12, 60);
    final int charsPerLine = (usableWidth / (_config.fontSize * 0.52)).floor().clamp(25, 90);
    final int dynamicBudget = (linesPerPage * charsPerLine).clamp(1200, 3200);

    final blockRegex = RegExp(
      r'<(?:p|div|h[1-6]|blockquote|hr|img|image|svg|figure|table|ul|ol)[^>]*>[\s\S]*?<\/(?:p|div|h[1-6]|blockquote|hr|svg|figure|table|ul|ol)>|<(?:hr|img|image)[^>]*\/?>',
      caseSensitive: false,
    );

    final matches = blockRegex.allMatches(html).toList();
    if (matches.isEmpty) {
      _splitTextIntoPages(size);
      return;
    }

    final List<String> pages = [];
    final StringBuffer currentChunk = StringBuffer();
    int currentLength = 0;

    for (final m in matches) {
      final block = m.group(0)!;
      final textLength = block.replaceAll(RegExp(r'<[^>]+>'), '').length;

      if (currentLength + textLength > dynamicBudget && currentChunk.isNotEmpty) {
        pages.add(currentChunk.toString());
        currentChunk.clear();
        currentLength = 0;
      }

      currentChunk.writeln(block);
      currentLength += textLength;
    }

    if (currentChunk.isNotEmpty) {
      pages.add(currentChunk.toString());
    }

    _pageChunks = pages.isNotEmpty ? pages : [html];
  }

  void _splitTextIntoPages(Size size) {
    final text = _currentChapter.plainTextContent;
    if (text.isEmpty) {
      if (_currentChapter.imageSrcs.isNotEmpty) {
        _pageChunks = [_currentChapter.imageSrcs.map((src) => '[EPILOGUE_IMG:$src]').join('\n')];
      } else {
        _pageChunks = ['[This chapter contains no text content]'];
      }
      return;
    }

    final double margin = _config.horizontalMargin > 0 ? _config.horizontalMargin : 20.0;
    final double usableHeight = (size.height - 120.0).clamp(300.0, 2400.0);
    final double usableWidth = (size.width - (margin * 2)).clamp(200.0, 1600.0);

    final double lineHeight = _config.fontSize * _config.lineSpacing;
    final int linesPerPage = (usableHeight / lineHeight).floor().clamp(12, 60);
    final int charsPerLine = (usableWidth / (_config.fontSize * 0.52)).floor().clamp(25, 90);
    final int dynamicBudget = (linesPerPage * charsPerLine).clamp(1200, 3200);

    final paragraphs = text.split('\n');
    final List<String> pages = [];
    final StringBuffer currentChunk = StringBuffer();
    int currentLength = 0;

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;

      if (currentLength + trimmed.length > dynamicBudget && currentChunk.isNotEmpty) {
        pages.add(currentChunk.toString().trim());
        currentChunk.clear();
        currentLength = 0;
      }

      if (trimmed.length > dynamicBudget) {
        final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
        for (final s in sentences) {
          if (currentLength + s.length > dynamicBudget && currentChunk.isNotEmpty) {
            pages.add(currentChunk.toString().trim());
            currentChunk.clear();
            currentLength = 0;
          }
          currentChunk.write('$s ');
          currentLength += s.length + 1;
        }
        currentChunk.writeln();
      } else {
        currentChunk.writeln(trimmed);
        currentChunk.writeln();
        currentLength += trimmed.length + 2;
      }
    }

    if (currentChunk.isNotEmpty) {
      pages.add(currentChunk.toString().trim());
    }

    _pageChunks = pages.isNotEmpty ? pages : [text];
  }

  Future<void> _goToChapter(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.chapters.length) return;
    _commitSession();
    final prevIndex = _currentChapterIndex;

    // JIT Lazy loading if chapter content is placeholder
    if (!widget.chapters[newIndex].isLoaded) {
      try {
        final loaded = await EpubParserService.loadChapterLazy(widget.book.filePath, newIndex);
        widget.chapters[newIndex] = loaded;
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _currentChapterIndex = newIndex;
      _currentPageIndex = 0;
      if (_lastMeasuredSize != null) {
        _prepareChapter(_lastMeasuredSize!);
      }
    });

    // Background prefetch adjacent chapters
    if (newIndex + 1 < widget.chapters.length && !widget.chapters[newIndex + 1].isLoaded) {
      EpubParserService.loadChapterLazy(widget.book.filePath, newIndex + 1).then((ch) {
        if (mounted) widget.chapters[newIndex + 1] = ch;
      });
    }
    if (newIndex - 1 >= 0 && !widget.chapters[newIndex - 1].isLoaded) {
      EpubParserService.loadChapterLazy(widget.book.filePath, newIndex - 1).then((ch) {
        if (mounted) widget.chapters[newIndex - 1] = ch;
      });
    }

    if (newIndex > prevIndex) {
      if (Random().nextDouble() < 0.35) {
        _triggerConstellationReaction();
      }
    }

    _initialPositionRestored = true;
    _currentPageIndex = 0;
    _lastScrollOffset = 0.0;
    _lastRecordedOffset = 0.0;
    _updateProgress();
    if (_config.pageAnimation != PageAnimationType.continuousScroll) {
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    } else {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  void _updateProgress() {
    final total = widget.chapters.length;
    final progress = total > 0 ? (((_currentChapterIndex + 1) / total) * 100).clamp(0.0, 100.0) : 0.0;
    final double currentOffset = _scrollController.hasClients ? _scrollController.offset : _lastScrollOffset;
    widget.storageService.updateBookProgress(
      bookId: widget.book.id,
      chapterIndex: _currentChapterIndex,
      progressPercent: progress,
      scrollOffset: currentOffset,
      pageIndex: _currentPageIndex,
    );
  }

  void _toggleHud() {
    _recordInteraction();
    setState(() => _hudVisible = !_hudVisible);
  }

  void _openSettings() {
    _recordInteraction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BottomSheetReaderSettings(
        config: _config,
        storageService: widget.storageService,
        currentChapterIndex: _currentChapterIndex,
        totalChapters: widget.chapters.length,
        onChapterSeek: (targetIdx) {
          _goToChapter(targetIdx);
        },
        onConfigChanged: (newConfig) {
          setState(() {
            _config = newConfig;
            if (_lastMeasuredSize != null) {
              _prepareChapter(_lastMeasuredSize!);
            }
          });
          widget.storageService.saveConfig(newConfig);
        },
      ),
    );
  }

  void _openToc() {
    _recordInteraction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ModernTocBottomSheet(
        chapters: widget.chapters,
        currentChapterIndex: _currentChapterIndex,
        onChapterSelected: (idx) {
          Navigator.pop(context);
          _goToChapter(idx);
        },
      ),
    );
  }

  void _toggleBookmark() async {
    _recordInteraction();
    final snippet = _currentChapter.plainTextContent.isNotEmpty
        ? _currentChapter.plainTextContent.substring(0, min(120, _currentChapter.plainTextContent.length))
        : widget.book.title;

    final bookmark = Bookmark(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      bookId: widget.book.id,
      chapterIndex: _currentChapterIndex,
      chapterTitle: _currentChapter.title,
      scrollOffset: _currentPageIndex.toDouble(),
      snippet: snippet.replaceAll('\n', ' ').trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await widget.storageService.addBookmark(bookmark);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmarked Chapter ${_currentChapterIndex + 1}'),
          backgroundColor: EpilogueTheme.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Color _getBackgroundColor() {
    if (_fourthWallActive) return EpilogueTheme.background;
    switch (_config.themePreset) {
      case ReaderThemePreset.paperLight:
        return const Color(0xFFFFFFFF);
      case ReaderThemePreset.sepiaWarm:
        return const Color(0xFFFBF0D9);
      case ReaderThemePreset.slateGray:
        return const Color(0xFF27272A);
      case ReaderThemePreset.oledDark:
        return const Color(0xFF000000);
    }
  }

  Color _getForegroundColor() {
    if (_fourthWallActive) return EpilogueTheme.textPrimary;
    switch (_config.themePreset) {
      case ReaderThemePreset.paperLight:
        return const Color(0xFF111827);
      case ReaderThemePreset.sepiaWarm:
        return const Color(0xFF382D1D);
      case ReaderThemePreset.slateGray:
        return const Color(0xFFE4E4E7);
      case ReaderThemePreset.oledDark:
        return const Color(0xFFD4D4D8);
    }
  }

  String get _fontFamily {
    switch (_config.fontFamily) {
      case 'sans':
        return 'sans-serif';
      case 'mono':
        return 'monospace';
      case 'serif':
      default:
        return 'serif';
    }
  }

  void _showFullscreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _getBackgroundColor();
    final fg = _getForegroundColor();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: !_config.fullscreenReader,
        bottom: !_config.fullscreenReader,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

            if (_lastMeasuredSize == null ||
                (_lastMeasuredSize!.width != viewportSize.width ||
                    _lastMeasuredSize!.height != viewportSize.height)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _prepareChapter(viewportSize));
                }
              });
            }

            return Stack(
              children: [
                // Reading Canvas with SelectionArea
                SelectionArea(
                  onSelectionChanged: (content) {
                    final text = content?.plainText ?? '';
                    if (text != _selectedTextContent) {
                      setState(() => _selectedTextContent = text);
                    }
                  },
                  contextMenuBuilder: (context, selectableRegionState) {
                    _selectableRegionState = selectableRegionState;
                    // Hide toolbar when selection is cleared
                    if (_selectedTextContent.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final buttonItems = selectableRegionState.contextMenuButtonItems;
                    final selectedText = _selectedTextContent;

                    final customItem = ContextMenuButtonItem(
                      label: '★ Highlight / Note',
                      onPressed: () {
                        selectableRegionState.hideToolbar();
                        if (selectedText.trim().isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (_) => DialogCreateHighlight(
                              bookId: widget.book.id,
                              bookTitle: widget.book.title,
                              chapterIndex: _currentChapterIndex,
                              chapterTitle: _currentChapter.title,
                              selectedText: selectedText,
                              storageService: widget.storageService,
                              onSaved: () {
                                setState(() {});
                              },
                            ),
                          );
                        }
                      },
                    );

                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: selectableRegionState.contextMenuAnchors,
                      buttonItems: [customItem, ...buttonItems],
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      // Any tap clears text selection and hides toolbar
                      if (_selectedTextContent.isNotEmpty) {
                        _selectableRegionState?.clearSelection();
                        _selectableRegionState?.hideToolbar();
                        setState(() => _selectedTextContent = '');
                      }
                      final width = constraints.maxWidth;
                      final dx = details.globalPosition.dx;
                      if (dx < width * 0.25) {
                        _recordInteraction();
                        if (_config.pageAnimation != PageAnimationType.continuousScroll) {
                          if (_currentPageIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          } else if (_currentChapterIndex > 0) {
                            _goToChapter(_currentChapterIndex - 1);
                          }
                        }
                      } else if (dx > width * 0.75) {
                        _recordInteraction();
                        if (_config.pageAnimation != PageAnimationType.continuousScroll) {
                          if (_currentPageIndex < _pageChunks.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          } else if (_currentChapterIndex < widget.chapters.length - 1) {
                            _goToChapter(_currentChapterIndex + 1);
                          }
                        }
                      } else {
                        _toggleHud();
                      }
                    },
                    child: _config.pageAnimation == PageAnimationType.continuousScroll
                        ? _buildContinuousScrollView(fg)
                        : _buildPagedView(fg),
                  ),
                ),

                // Top Header Overlay
                if (_config.showReadingHeaderFooter && !_hudVisible)
                  Positioned(
                    top: 8,
                    left: _config.horizontalMargin,
                    right: _config.horizontalMargin,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.book.title,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: fg.withValues(alpha: 0.45),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _currentChapter.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: fg.withValues(alpha: 0.45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                // Bottom Footer Overlay
                if (_config.showReadingHeaderFooter && !_hudVisible)
                  Positioned(
                    bottom: 8,
                    left: _config.horizontalMargin,
                    right: _config.horizontalMargin,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ch. ${_currentChapterIndex + 1} / ${widget.chapters.length}',
                          style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.4)),
                        ),
                        Text(
                          _config.pageAnimation == PageAnimationType.continuousScroll
                              ? '${(((_currentChapterIndex + 1) / widget.chapters.length) * 100).toStringAsFixed(1)}%'
                              : 'Page ${_currentPageIndex + 1} / ${_pageChunks.length}',
                          style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),

                // Glowing Constellation Reaction Toast
                if (_activeConstellationEvent != null)
                  Positioned(
                    top: 24,
                    left: 20,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EpilogueTheme.cyanAccent, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: EpilogueTheme.cyanAccent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "[The constellation '${_activeConstellationEvent!.modifier}' ${_activeConstellationEvent!.message}]",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_activeConstellationEvent!.coinsSponsored > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                "+${_activeConstellationEvent!.coinsSponsored} Coins Sponsored!",
                                style: TextStyle(
                                  color: EpilogueTheme.starGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // Top HUD
                if (_hudVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: EpilogueTheme.surface.withValues(alpha: 0.97),
                        border: Border(bottom: BorderSide(color: EpilogueTheme.border)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: EpilogueTheme.textPrimary),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              _currentChapter.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: EpilogueTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              color: _fourthWallActive ? EpilogueTheme.cyanAccent.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _fourthWallActive ? EpilogueTheme.cyanAccent.withValues(alpha: 0.5) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              tooltip: 'The 4th Wall Glow Mode',
                              icon: Icon(
                                _fourthWallActive ? Icons.shield : Icons.shield_outlined,
                                color: _fourthWallActive ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                _recordInteraction();
                                setState(() => _fourthWallActive = !_fourthWallActive);
                                final updated = _config.copyWith(fourthWallActive: _fourthWallActive);
                                EpilogueTheme.applyConfig(updated);
                                widget.storageService.saveConfig(updated);

                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _fourthWallActive
                                          ? '[The exclusive skill, \'The 4th Wall\' has been activated.]'
                                          : '[The exclusive skill, \'The 4th Wall\' has been deactivated.]',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                        color: Color(0xFFE6F1FF),
                                      ),
                                    ),
                                    backgroundColor: _fourthWallActive ? const Color(0xFF0A192F) : EpilogueTheme.accent,
                                    duration: const Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: _fourthWallActive ? const Color(0xFF64FFDA) : EpilogueTheme.border,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add Bookmark',
                            icon: Icon(Icons.bookmark_border, color: EpilogueTheme.textPrimary),
                            onPressed: _toggleBookmark,
                          ),
                          IconButton(
                            tooltip: 'Reader Settings',
                            icon: Icon(Icons.tune, color: EpilogueTheme.textPrimary),
                            onPressed: _openSettings,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom HUD (Chapter Scrubber & Navigation)
                if (_hudVisible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: EpilogueTheme.surface.withValues(alpha: 0.97),
                        border: Border(top: BorderSide(color: EpilogueTheme.border)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.skip_previous, color: EpilogueTheme.textPrimary),
                                onPressed: _currentChapterIndex > 0 ? () => _goToChapter(_currentChapterIndex - 1) : null,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _currentChapterIndex.toDouble(),
                                  min: 0,
                                  max: max(0, (widget.chapters.length - 1).toDouble()),
                                  divisions: max(1, widget.chapters.length - 1),
                                  activeColor: EpilogueTheme.accent,
                                  onChanged: (val) {
                                    _recordInteraction();
                                    _goToChapter(val.round());
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.skip_next, color: EpilogueTheme.textPrimary),
                                onPressed: _currentChapterIndex < widget.chapters.length - 1
                                    ? () => _goToChapter(_currentChapterIndex + 1)
                                    : null,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _openToc,
                                icon: Icon(Icons.list_alt, size: 18, color: EpilogueTheme.accent),
                                label: Text('Table of Contents', style: TextStyle(color: EpilogueTheme.accent, fontSize: 13)),
                              ),
                              Text(
                                '${_currentChapterIndex + 1} / ${widget.chapters.length}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPagedView(Color fg) {
    if (_pageChunks.isEmpty) {
      return Center(child: CircularProgressIndicator(color: EpilogueTheme.accent));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _pageChunks.length,
      onPageChanged: (idx) {
        _recordInteraction();
        _activeWords += 150;
        setState(() => _currentPageIndex = idx);
        _updateProgress();
      },
      itemBuilder: (context, pageIdx) {
        final chunk = _pageChunks[pageIdx];
        final margin = _config.horizontalMargin > 0 ? _config.horizontalMargin : 20.0;

        return Padding(
          padding: EdgeInsets.only(
            left: margin,
            right: margin,
            top: _config.showReadingHeaderFooter ? 28.0 : 16.0,
            bottom: _config.showReadingHeaderFooter ? 28.0 : 16.0,
          ),
          child: _config.useOriginalBookStyles
              ? SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildHtmlWidget(chunk, fg),
                )
              : _buildTextParagraphs(chunk, fg),
        );
      },
    );
  }

  Widget _buildContinuousScrollView(Color fg) {
    _restoreInitialPositionIfNeeded();
    final margin = _config.horizontalMargin > 0 ? _config.horizontalMargin : 20.0;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: margin,
        vertical: _config.showReadingHeaderFooter ? 36.0 : 20.0,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            _currentChapter.title,
            style: TextStyle(
              fontSize: _config.fontSize * 1.4,
              fontWeight: FontWeight.bold,
              fontFamily: _fontFamily,
              color: fg,
            ),
          ),
        ),
        if (_config.useOriginalBookStyles)
          _buildHtmlWidget(_currentChapter.htmlContent, fg)
        else
          _buildTextParagraphs(_currentChapter.plainTextContent, fg),
        const SizedBox(height: 60),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentChapterIndex > 0)
              OutlinedButton.icon(
                onPressed: () => _goToChapter(_currentChapterIndex - 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous Chapter'),
              )
            else
              const SizedBox.shrink(),
            if (_currentChapterIndex < widget.chapters.length - 1)
              FilledButton.icon(
                onPressed: () => _goToChapter(_currentChapterIndex + 1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Chapter'),
                style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildTextParagraphs(String content, Color fg) {
    final paragraphs = content.split('\n');
    final chapterImages = _getChapterImages();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentPageIndex == 0) ...[
          Text(
            _currentChapter.title,
            style: TextStyle(
              fontSize: _config.fontSize * 1.35,
              fontWeight: FontWeight.bold,
              fontFamily: _fontFamily,
              color: fg,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_currentPageIndex == 0 && chapterImages.isNotEmpty) ...[
          _buildImagesCarousel(chapterImages),
          const SizedBox(height: 20),
        ],
        for (final p in paragraphs) _buildStyledParagraph(p, fg, context),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildRenderedImage(String src) {
    if (src.isEmpty) return const SizedBox.shrink();

    if (src.startsWith('data:image/')) {
      try {
        final commaIdx = src.indexOf(',');
        if (commaIdx != -1) {
          final base64Data = src.substring(commaIdx + 1);
          final bytes = base64Decode(base64Data);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          );
        }
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    final localPath = EpubParserService.resolveImagePath(
      imageIndex: _bookImageFiles,
      src: src,
      chapterHref: _currentChapter.contentFileName,
    );

    if (localPath != null && File(localPath).existsSync()) {
      return GestureDetector(
        onTap: () => _showFullscreenImage(localPath),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(localPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHtmlWidget(String html, Color fg) {
    final styledHtml = (_bookCss.isNotEmpty) ? '<style>$_bookCss</style>$html' : html;

    return Html(
      data: styledHtml,
      extensions: [
        TagExtension(
          tagsToExtend: {'img', 'image', 'svg'},
          builder: (extensionContext) {
            String? src = extensionContext.attributes['src'] ??
                extensionContext.attributes['xlink:href'] ??
                extensionContext.attributes['href'];

            if (src == null && extensionContext.elementName.toLowerCase() == 'svg') {
              final element = extensionContext.element;
              if (element != null) {
                final imageChild = element.getElementsByTagName('image');
                if (imageChild.isNotEmpty) {
                  final imgEl = imageChild.first;
                  src = imgEl.attributes['xlink:href'] ??
                      imgEl.attributes['href'] ??
                      imgEl.attributes['src'];
                }
              }
            }

            if (src == null || src.isEmpty) return const SizedBox.shrink();
            return _buildRenderedImage(src);
          },
        ),
      ],
      style: {
        'html': Style(
          fontSize: FontSize(_config.fontSize),
          lineHeight: LineHeight(_config.lineSpacing),
          color: fg,
          fontFamily: _fontFamily,
          padding: HtmlPaddings.zero,
          margin: Margins.zero,
        ),
        'body': Style(
          fontSize: FontSize(_config.fontSize),
          lineHeight: LineHeight(_config.lineSpacing),
          color: fg,
          fontFamily: _fontFamily,
          padding: HtmlPaddings.zero,
          margin: Margins.zero,
        ),
        'p': Style(
          margin: Margins.only(bottom: _config.fontSize * 0.75),
          lineHeight: LineHeight(_config.lineSpacing),
          color: fg,
          fontFamily: _fontFamily,
        ),
        'blockquote': Style(
          margin: Margins.symmetric(horizontal: 16, vertical: 8),
          padding: HtmlPaddings.all(8),
          color: fg.withValues(alpha: 0.85),
          border: Border(left: BorderSide(color: EpilogueTheme.accent, width: 3)),
        ),
        'hr': Style(
          margin: Margins.symmetric(vertical: 12),
          border: Border(bottom: BorderSide(color: EpilogueTheme.border, width: 1)),
        ),
      },
    );
  }

  List<String> _getChapterImages() {
    final List<String> list = [];
    for (final src in _currentChapter.imageSrcs) {
      final localPath = EpubParserService.resolveImagePath(
        imageIndex: _bookImageFiles,
        src: src,
        chapterHref: _currentChapter.contentFileName,
      );
      if (localPath != null && File(localPath).existsSync()) {
        if (!list.contains(localPath)) {
          list.add(localPath);
        }
      }
    }
    return list;
  }

  Widget _buildImagesCarousel(List<String> images) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final path = images[idx];
          return GestureDetector(
            onTap: () => _showFullscreenImage(path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.file(
                    File(path),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyledParagraph(String text, Color fg, BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (trimmed.contains('[EPILOGUE_IMG:') && trimmed.contains(']')) {
      final pattern = RegExp(r'\[EPILOGUE_IMG:([^\]]+)\]');
      final matches = pattern.allMatches(trimmed).toList();
      if (matches.isNotEmpty) {
        if (trimmed.startsWith('[EPILOGUE_IMG:') && trimmed.endsWith(']') && matches.length == 1) {
          return _buildRenderedImage(matches.first.group(1)!);
        }
        final List<Widget> children = [];
        int lastEnd = 0;
        for (final match in matches) {
          if (match.start > lastEnd) {
            final prefix = trimmed.substring(lastEnd, match.start).trim();
            if (prefix.isNotEmpty) {
              children.add(Text(
                prefix,
                style: TextStyle(
                  fontSize: _config.fontSize,
                  height: _config.lineSpacing,
                  fontFamily: _fontFamily,
                  color: fg,
                  letterSpacing: 0.2,
                ),
              ));
            }
          }
          children.add(_buildRenderedImage(match.group(1)!));
          lastEnd = match.end;
        }
        if (lastEnd < trimmed.length) {
          final suffix = trimmed.substring(lastEnd).trim();
          if (suffix.isNotEmpty) {
            children.add(Text(
              suffix,
              style: TextStyle(
                fontSize: _config.fontSize,
                height: _config.lineSpacing,
                fontFamily: _fontFamily,
                color: fg,
                letterSpacing: 0.2,
              ),
            ));
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
    }

    final isConstellationMsg = _config.customCssEnabled &&
        trimmed.startsWith('[') &&
        (trimmed.endsWith(']') || trimmed.endsWith('].') || trimmed.endsWith(']"'));

    if (isConstellationMsg) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _fourthWallActive
              ? const Color(0xFF042F2E).withValues(alpha: 0.5)
              : const Color(0xFF06B6D4).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _fourthWallActive ? const Color(0xFF2DD4BF) : const Color(0xFF06B6D4),
            width: 1.2,
          ),
        ),
        child: Text(
          trimmed,
          style: TextStyle(
            fontSize: _config.fontSize - 1,
            height: _config.lineSpacing,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: _fourthWallActive ? const Color(0xFF5EEAD4) : const Color(0xFF0891B2),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: _config.fontSize * 0.75),
      child: Text(
        trimmed,
        style: TextStyle(
          fontSize: _config.fontSize,
          height: _config.lineSpacing,
          fontFamily: _fontFamily,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
