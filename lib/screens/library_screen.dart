import 'dart:io';
import 'package:flutter/material.dart';
import '../config/reader_config.dart';
import '../models/book_info.dart';
import '../models/book_shelf.dart';
import '../models/chapter.dart';
import '../services/epub_parser_service.dart';
import '../services/file_explorer_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';
import '../widgets/bottom_sheet_book_detail.dart';
import '../widgets/dialog_edit_metadata.dart';
import 'in_app_file_explorer_screen.dart';
import 'modern_reader_screen.dart';
import 'retrocognition_screen.dart';

enum BookSortOrder {
  lastRead,
  progress,
  wordCount,
  title,
  fileSize,
}

class LibraryScreen extends StatefulWidget {
  final StorageService storageService;
  final ReaderConfig config;
  final VoidCallback? onSettingsChanged;

  const LibraryScreen({
    super.key,
    required this.storageService,
    required this.config,
    this.onSettingsChanged,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<BookInfo> _books = [];
  List<BookShelf> _shelves = [];
  String _selectedShelfId = 'all';
  BookSortOrder _sortOrder = BookSortOrder.lastRead;

  bool _isLoading = false;
  bool _isGridView = true;
  bool _isBackfilling = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late FileExplorerService _explorerService;

  @override
  void initState() {
    super.initState();
    _explorerService = FileExplorerService(widget.storageService);
    _isGridView = widget.storageService.isGridView();
    _loadBooksAndShelves();
    _autoSyncOnStartup();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBooksAndShelves() {
    final cached = widget.storageService.loadBooks();
    final loadedShelves = widget.storageService.loadShelves();
    setState(() {
      _books = cached;
      _shelves = loadedShelves;
    });

    _backfillCoversIfNeeded(cached);
  }

  Future<void> _autoSyncOnStartup() async {
    final config = widget.storageService.loadConfig();
    final folder = config.libraryFolderPath ?? '${FileExplorerService.rootStoragePath}/Documents/Books';
    if (Directory(folder).existsSync()) {
      await _syncLibrary(showSnackBar: false);
    }
  }

  Future<void> _syncLibrary({bool showSnackBar = true}) async {
    final config = widget.storageService.loadConfig();
    final folder = config.libraryFolderPath ?? '${FileExplorerService.rootStoragePath}/Documents/Books';
    if (!Directory(folder).existsSync()) {
      _loadBooksAndShelves();
      return;
    }

    final newCount = await _explorerService.syncLibraryFolder(folder);
    _loadBooksAndShelves();

    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newCount > 0
              ? 'Library synced! Added $newCount new novel(s).'
              : 'Library is up to date.'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  Future<void> _backfillCoversIfNeeded(List<BookInfo> books) async {
    if (_isBackfilling) return;
    final missing = books.where((b) => b.coverImagePath == null || !File(b.coverImagePath!).existsSync()).toList();
    if (missing.isEmpty) return;

    _isBackfilling = true;
    bool hasUpdates = false;
    final updatedList = List<BookInfo>.from(widget.storageService.loadBooks());

    for (final book in missing) {
      try {
        final cover = await EpubParserService.extractCoverImage(book.filePath);
        final idx = updatedList.indexWhere((b) => b.id == book.id);
        if (idx >= 0) {
          if (cover != null && File(cover).existsSync()) {
            updatedList[idx] = updatedList[idx].copyWith(coverImagePath: cover);
            hasUpdates = true;
          } else {
            updatedList[idx] = updatedList[idx].copyWith(coverImagePath: 'none');
            hasUpdates = true;
          }
        }
      } catch (_) {}
    }

    _isBackfilling = false;
    if (hasUpdates && mounted) {
      await widget.storageService.saveBooks(updatedList);
      setState(() {
        _books = updatedList;
      });
    }
  }

  Future<void> _openBook(BookInfo book) async {
    setState(() => _isLoading = true);
    List<Chapter> chapters;

    try {
      chapters = await EpubParserService.loadInitialChapterWindow(
        book.filePath,
        initialChapterIndex: book.lastReadChapterIndex,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract EPUB chapters: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = false);
    if (!mounted || chapters.isEmpty) return;

    // Auto-assign to reading shelf if not completed
    if (book.lastReadProgressPercent < 98.0) {
      await widget.storageService.addBookToShelf('reading', book.id);
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernReaderScreen(
          book: book,
          chapters: chapters,
          initialChapterIndex: book.lastReadChapterIndex,
          config: widget.config,
          storageService: widget.storageService,
        ),
      ),
    );

    _loadBooksAndShelves();
  }

  void _showBookDetails(BookInfo book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetBookDetail(
        book: book,
        storageService: widget.storageService,
        onOpenBook: () => _openBook(book),
        onUpdated: _loadBooksAndShelves,
      ),
    );
  }

  void _showEditMetadataDialog(BookInfo book) {
    showDialog(
      context: context,
      builder: (_) => DialogEditMetadata(
        book: book,
        storageService: widget.storageService,
        onUpdated: _loadBooksAndShelves,
      ),
    );
  }

  void _confirmRemoveBook(BookInfo book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Remove from Library', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${book.title}" from your library catalog?\n\n(The EPUB file on your device storage will NOT be deleted).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              await widget.storageService.removeBook(book.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadBooksAndShelves();
            },
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.dangerAccent),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _markBookAsRead(BookInfo book) async {
    await widget.storageService.markBookAsFullyRead(book.id);
    _loadBooksAndShelves();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${book.title}" as 100% Completed!'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  void _showAssignShelfDialog(BookInfo book) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentShelves = widget.storageService.loadShelves();
            return AlertDialog(
              backgroundColor: EpilogueTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: EpilogueTheme.border),
              ),
              title: const Text('Assign to Shelves'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: currentShelves.where((s) => s.id != 'all').map((shelf) {
                    final isChecked = shelf.bookIds.contains(book.id);
                    return CheckboxListTile(
                      title: Text(shelf.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      value: isChecked,
                      activeColor: EpilogueTheme.accent,
                      onChanged: (val) async {
                        if (val == true) {
                          await widget.storageService.addBookToShelf(shelf.id, book.id);
                        } else {
                          await widget.storageService.removeBookFromShelf(shelf.id, book.id);
                        }
                        setDialogState(() {});
                        _loadBooksAndShelves();
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
                  child: const Text('DONE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddNewShelfDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Create New Shelf'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Shelf Name (e.g. Progression Fantasy)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final shelves = widget.storageService.loadShelves();
                final newShelf = BookShelf(
                  id: 'shelf_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                );
                shelves.add(newShelf);
                await widget.storageService.saveShelves(shelves);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadBooksAndShelves();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BookInfo book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: EpilogueTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: EpilogueTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildCoverThumbnail(book, width: 44, height: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: EpilogueTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            book.author,
                            style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: EpilogueTheme.border),
              ListTile(
                leading: Icon(Icons.play_circle_outline, color: EpilogueTheme.accent),
                title: const Text('Read Novel', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBook(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: EpilogueTheme.starGold),
                title: const Text('Mark as Fully Read (100%)', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _markBookAsRead(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.collections_bookmark_outlined, color: EpilogueTheme.cyanAccent),
                title: const Text('Assign to Shelves', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAssignShelfDialog(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: EpilogueTheme.textPrimary),
                title: const Text('View Details & Telemetry', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBookDetails(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: EpilogueTheme.cyanAccent),
                title: const Text('Edit Metadata & Cover', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMetadataDialog(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: EpilogueTheme.dangerAccent),
                title: Text('Remove from Library', style: TextStyle(color: EpilogueTheme.dangerAccent, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveBook(book);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openFileExplorer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppFileExplorerScreen(
          storageService: widget.storageService,
          onBookSelected: (b) => _openBook(b),
        ),
      ),
    );
    _loadBooksAndShelves();
  }

  void _openRetrocognition() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetrocognitionScreen(storageService: widget.storageService),
      ),
    );
    _loadBooksAndShelves();
  }

  Widget _buildCoverThumbnail(BookInfo book, {required double width, required double height, double borderRadius = 8}) {
    final hasCover = book.coverImagePath != null && File(book.coverImagePath!).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: EpilogueTheme.surfaceElevated,
          border: Border.all(color: EpilogueTheme.border),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: hasCover
            ? Image.file(
                File(book.coverImagePath!),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.book, color: EpilogueTheme.accent, size: 24),
                ),
              )
            : Center(
                child: Icon(Icons.book, color: EpilogueTheme.accent, size: 24),
              ),
      ),
    );
  }

  List<BookInfo> _filterAndSortBooks() {
    List<BookInfo> list = List.from(_books);

    // 1. Search Query Filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
    }

    // 2. Shelf Filter
    if (_selectedShelfId != 'all') {
      final shelf = _shelves.firstWhere((s) => s.id == _selectedShelfId, orElse: () => const BookShelf(id: '', name: ''));
      if (_selectedShelfId == 'reading') {
        list = list.where((b) => (b.lastReadProgressPercent > 0 && b.lastReadProgressPercent < 98.0) || shelf.bookIds.contains(b.id)).toList();
      } else if (_selectedShelfId == 'completed') {
        list = list.where((b) => b.lastReadProgressPercent >= 98.0 || shelf.bookIds.contains(b.id)).toList();
      } else {
        list = list.where((b) => shelf.bookIds.contains(b.id)).toList();
      }
    }

    // 3. Multi-Criteria Sort
    switch (_sortOrder) {
      case BookSortOrder.lastRead:
        list.sort((a, b) {
          final aRead = a.lastReadTimestamp ?? 0;
          final bRead = b.lastReadTimestamp ?? 0;
          if (bRead != aRead) {
            return bRead.compareTo(aRead);
          }
          final aAdded = a.addedTimestamp ?? 0;
          final bAdded = b.addedTimestamp ?? 0;
          if (bAdded != aAdded) {
            return bAdded.compareTo(aAdded);
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case BookSortOrder.progress:
        list.sort((a, b) => b.lastReadProgressPercent.compareTo(a.lastReadProgressPercent));
        break;
      case BookSortOrder.wordCount:
        list.sort((a, b) => b.totalWordsRead.compareTo(a.totalWordsRead));
        break;
      case BookSortOrder.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case BookSortOrder.fileSize:
        list.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final lastRead = widget.storageService.getLastReadBook();
    final filtered = _filterAndSortBooks();

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: Text(
          'Epilogue',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
            color: EpilogueTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Retrocognition (Sync Past Progress)',
            icon: Icon(Icons.history_edu, color: EpilogueTheme.starGold),
            onPressed: _openRetrocognition,
          ),
          IconButton(
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: EpilogueTheme.textPrimary,
            ),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              widget.storageService.setGridView(_isGridView);
            },
          ),
          IconButton(
            tooltip: 'Browse Files',
            icon: Icon(Icons.add_circle_outline, size: 26, color: EpilogueTheme.textPrimary),
            onPressed: _openFileExplorer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: EpilogueTheme.accent))
          : RefreshIndicator(
              onRefresh: () => _syncLibrary(showSnackBar: true),
              color: EpilogueTheme.accent,
              backgroundColor: EpilogueTheme.surface,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Quick Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: TextStyle(color: EpilogueTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search archive...',
                      hintStyle: TextStyle(color: EpilogueTheme.textMuted),
                      prefixIcon: Icon(Icons.search, color: EpilogueTheme.textSecondary),
                      filled: true,
                      fillColor: EpilogueTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: EpilogueTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: EpilogueTheme.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Shelf Chips Bar
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final shelf in _shelves) ...[
                          _buildShelfChip(shelf),
                          const SizedBox(width: 8),
                        ],
                        ActionChip(
                          avatar: Icon(Icons.add, size: 16, color: EpilogueTheme.accent),
                          label: const Text('Add Shelf', style: TextStyle(fontSize: 12)),
                          backgroundColor: EpilogueTheme.surface,
                          side: BorderSide(color: EpilogueTheme.border),
                          onPressed: _showAddNewShelfDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sort & Count Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} novel${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<BookSortOrder>(
                          value: _sortOrder,
                          icon: Icon(Icons.sort, size: 18, color: EpilogueTheme.textSecondary),
                          items: const [
                            DropdownMenuItem(value: BookSortOrder.lastRead, child: Text('Sort: Last Read', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: BookSortOrder.progress, child: Text('Sort: Progress %', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: BookSortOrder.wordCount, child: Text('Sort: Words Read', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: BookSortOrder.title, child: Text('Sort: Title', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: BookSortOrder.fileSize, child: Text('Sort: File Size', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _sortOrder = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Resume reading card
                  if (lastRead != null && _searchQuery.isEmpty && _selectedShelfId == 'all') ...[
                    Card(
                      color: EpilogueTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: EpilogueTheme.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openBook(lastRead),
                        onLongPress: () => _showQuickActions(lastRead),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildCoverThumbnail(lastRead, width: 52, height: 72, borderRadius: 10),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'RESUME READING',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: EpilogueTheme.cyanAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      lastRead.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: EpilogueTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Chapter ${lastRead.lastReadChapterIndex + 1} (${lastRead.lastReadProgressPercent.toStringAsFixed(0)}% Read)',
                                      style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.play_circle_fill, color: EpilogueTheme.accent, size: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Library Books List or Grid
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: EpilogueTheme.surfaceElevated,
                              ),
                              child: Center(
                                child: Icon(Icons.auto_stories, size: 38, color: EpilogueTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Novels Found',
                              style: TextStyle(
                                color: EpilogueTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pull down to refresh or tap + to browse files',
                              style: TextStyle(
                                color: EpilogueTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isGridView)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.50,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final book = filtered[index];
                        return _buildGridCard(book);
                      },
                    )
                  else
                    for (final book in filtered) _buildListCard(book),
                ],
              ),
            ),
    );
  }

  Widget _buildShelfChip(BookShelf shelf) {
    final isSelected = _selectedShelfId == shelf.id;
    int count = 0;
    if (shelf.id == 'all') {
      count = _books.length;
    } else if (shelf.id == 'reading') {
      count = _books.where((b) => (b.lastReadProgressPercent > 0 && b.lastReadProgressPercent < 98.0) || shelf.bookIds.contains(b.id)).length;
    } else if (shelf.id == 'completed') {
      count = _books.where((b) => b.lastReadProgressPercent >= 98.0 || shelf.bookIds.contains(b.id)).length;
    } else {
      count = _books.where((b) => shelf.bookIds.contains(b.id)).length;
    }

    return FilterChip(
      selected: isSelected,
      label: Text('${shelf.name} ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : EpilogueTheme.textPrimary,
      ),
      backgroundColor: EpilogueTheme.surface,
      selectedColor: EpilogueTheme.accent,
      checkmarkColor: Colors.white,
      side: BorderSide(color: isSelected ? EpilogueTheme.accent : EpilogueTheme.border),
      onSelected: (_) {
        setState(() => _selectedShelfId = shelf.id);
      },
    );
  }

  Widget _buildGridCard(BookInfo book) {
    return GestureDetector(
      onTap: () => _openBook(book),
      onLongPress: () => _showQuickActions(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.09),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (book.coverImagePath != null && File(book.coverImagePath!).existsSync())
                        ? Image.file(
                            File(book.coverImagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: EpilogueTheme.surfaceElevated,
                              child: Icon(Icons.book, size: 44, color: EpilogueTheme.accent),
                            ),
                          )
                        : Container(
                            color: EpilogueTheme.surfaceElevated,
                            child: Icon(Icons.book, size: 44, color: EpilogueTheme.accent),
                          ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _showQuickActions(book),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.more_vert, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (book.lastReadProgressPercent >= 98.0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: EpilogueTheme.starGold.withValues(alpha: 0.9),
                          child: const Center(
                            child: Text(
                              'COMPLETED',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (book.lastReadProgressPercent / 100).clamp(0.0, 1.0),
              backgroundColor: EpilogueTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(EpilogueTheme.accent),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${book.lastReadProgressPercent.toStringAsFixed(0)}% Read',
            style: TextStyle(fontSize: 10, color: EpilogueTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(BookInfo book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openBook(book),
        onLongPress: () => _showQuickActions(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCoverThumbnail(book, width: 48, height: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: EpilogueTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (book.lastReadProgressPercent / 100).clamp(0.0, 1.0),
                              backgroundColor: EpilogueTheme.border,
                              valueColor: AlwaysStoppedAnimation<Color>(EpilogueTheme.accent),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${book.lastReadProgressPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.accent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: EpilogueTheme.textSecondary),
                onPressed: () => _showQuickActions(book),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
