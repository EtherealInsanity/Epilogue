import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/book_info.dart';
import '../services/epub_parser_service.dart';
import '../services/orv_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class RetrocognitionScreen extends StatefulWidget {
  final StorageService storageService;

  const RetrocognitionScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<RetrocognitionScreen> createState() => _RetrocognitionScreenState();
}

class _BookProgressInput {
  final BookInfo book;
  int currentChapter;
  double progressPercent;
  int estimatedWpm;

  _BookProgressInput({
    required this.book,
    this.currentChapter = 1,
    this.progressPercent = 10.0,
    this.estimatedWpm = 220,
  });
}

class _RetrocognitionScreenState extends State<RetrocognitionScreen> {
  late OrvService _orvService;
  List<_BookProgressInput> _pendingBooks = [];
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _orvService = OrvService(widget.storageService);
    _initializeFromExistingLibrary();
  }

  void _initializeFromExistingLibrary() {
    final existing = widget.storageService.loadBooks();
    setState(() {
      _pendingBooks = existing.map((b) {
        final total = b.totalChapters > 0 ? b.totalChapters : 100;
        final ch = b.lastReadChapterIndex > 0 ? b.lastReadChapterIndex + 1 : 1;
        final prog = b.lastReadProgressPercent > 0 ? b.lastReadProgressPercent : (ch / total) * 100;
        return _BookProgressInput(
          book: b,
          currentChapter: ch.clamp(1, total),
          progressPercent: prog.clamp(0.0, 100.0),
          estimatedWpm: widget.storageService.getAverageReadingWpm(),
        );
      }).toList();
    });
  }

  Future<void> _pickAdditionalEpubs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        setState(() => _isProcessing = true);
        for (final path in result.paths) {
          if (path != null && File(path).existsSync()) {
            try {
              final book = await EpubParserService.parseMetadata(path);
              if (!_pendingBooks.any((p) => p.book.id == book.id)) {
                _pendingBooks.add(_BookProgressInput(
                  book: book,
                  currentChapter: 1,
                  progressPercent: 1.0,
                  estimatedWpm: widget.storageService.getAverageReadingWpm(),
                ));
              }
            } catch (_) {}
          }
        }
        setState(() => _isProcessing = false);
      }
    } catch (_) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeRetrocognition() async {
    if (_pendingBooks.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing past story worldlines...';
    });

    int totalAddedWords = 0;
    int totalAddedSeconds = 0;
    int totalCompletedVolumes = 0;

    for (int i = 0; i < _pendingBooks.length; i++) {
      final item = _pendingBooks[i];
      final book = item.book;
      setState(() {
        _statusMessage = 'Calculating chapter words for "${book.title}" (${i + 1}/${_pendingBooks.length})...';
      });

      int wordsPerChapter = 3500;
      try {
        final indexInfo = await EpubParserService.parseAndCacheBookIndex(book.filePath);
        if (indexInfo.chapterMetas.isNotEmpty) {
          final sampleChapter = await EpubParserService.loadChapterLazy(book.filePath, 0);
          if (sampleChapter.wordCount > 500) {
            wordsPerChapter = sampleChapter.wordCount;
          }
        }
      } catch (_) {}

      final targetChapterIdx = (item.currentChapter - 1).clamp(0, item.book.totalChapters > 0 ? item.book.totalChapters - 1 : 9999);
      final chaptersCount = targetChapterIdx + 1;
      final bookWords = chaptersCount * wordsPerChapter;
      final bookSeconds = ((bookWords / (item.estimatedWpm > 0 ? item.estimatedWpm : 220)) * 60).round();

      totalAddedWords += bookWords;
      totalAddedSeconds += bookSeconds;

      if (item.progressPercent >= 98.0 || (book.totalChapters > 0 && item.currentChapter >= book.totalChapters)) {
        totalCompletedVolumes++;
      }

      await widget.storageService.batchMarkChaptersRead(
        bookId: book.id,
        targetChapterIndex: targetChapterIdx,
        estimatedWordsPerChapter: wordsPerChapter,
      );
    }

    setState(() {
      _statusMessage = 'Synthesizing Star Stream Scenarios...';
    });

    final claimableScenarios = _orvService.evaluateScenarios();

    setState(() => _isProcessing = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: EpilogueTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: EpilogueTheme.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_stories, color: EpilogueTheme.starGold),
              SizedBox(width: 10),
              Text('Retrocognition Synchronized!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Synchronized reading history across ${_pendingBooks.length} novels:'),
              const SizedBox(height: 12),
              Text('• Words Inherited: ${totalAddedWords.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} words'),
              Text('• Time Accumulated: ${(totalAddedSeconds / 3600).toStringAsFixed(1)} hours'),
              Text('• Standard Pages: ${(totalAddedWords / 300).round()} pages'),
              if (totalCompletedVolumes > 0)
                Text('• Completed Volumes: $totalCompletedVolumes books'),
              if (claimableScenarios.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EpilogueTheme.starGold.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.stars, color: EpilogueTheme.starGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${claimableScenarios.length} Scenario(s) are now ready to be cleared! Head over to the Scenarios tab to claim your rewards.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
              child: const Text('ENTER STAR STREAM'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Retrocognition (과거 읽기 회상)'),
        actions: [
          IconButton(
            tooltip: 'Add EPUBs from device',
            icon: const Icon(Icons.add_circle_outline, color: EpilogueTheme.accent),
            onPressed: _isProcessing ? null : _pickAdditionalEpubs,
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: EpilogueTheme.accent),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Informational Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EpilogueTheme.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top, color: EpilogueTheme.cyanAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transitioning from another reader? Input your past chapter or percentage in each book. The EPUB engine will analyze word counts and seamlessly migrate your lifetime telemetry and Star Stream scenarios.',
                          style: TextStyle(fontSize: 12, color: EpilogueTheme.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_pendingBooks.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.library_books_outlined, size: 48, color: EpilogueTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text('No books selected yet', style: TextStyle(color: EpilogueTheme.textSecondary)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _pickAdditionalEpubs,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Pick EPUB Files'),
                            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  for (int i = 0; i < _pendingBooks.length; i++)
                    _buildBookInputCard(_pendingBooks[i], i),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _executeRetrocognition,
                    icon: const Icon(Icons.sync),
                    label: const Text('SYNCHRONIZE WITH STAR STREAM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: EpilogueTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
    );
  }

  Widget _buildBookInputCard(_BookProgressInput item, int index) {
    final book = item.book;
    final totalChapters = book.totalChapters > 0 ? book.totalChapters : 100;
    final hasCover = book.coverImagePath != null && File(book.coverImagePath!).existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EpilogueTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 60,
                    color: EpilogueTheme.surfaceElevated,
                    child: hasCover
                        ? Image.file(File(book.coverImagePath!), fit: BoxFit.cover)
                        : const Icon(Icons.book, color: EpilogueTheme.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: EpilogueTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Chapters: $totalChapters',
                        style: const TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: EpilogueTheme.textMuted),
                  onPressed: () {
                    setState(() => _pendingBooks.removeAt(index));
                  },
                ),
              ],
            ),
            const Divider(color: EpilogueTheme.border, height: 24),

            // Dual Input: Exact Chapter & Progress Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chapter ${item.currentChapter} of $totalChapters',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.progressPercent.toStringAsFixed(0)}% Read',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
            Slider(
              value: item.progressPercent,
              min: 0.0,
              max: 100.0,
              divisions: 100,
              activeColor: EpilogueTheme.accent,
              onChanged: (val) {
                setState(() {
                  item.progressPercent = val;
                  item.currentChapter = ((val / 100.0) * totalChapters).round().clamp(1, totalChapters);
                });
              },
            ),

            // Calibrated WPM Speed Adjustment
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Reading Speed: ${item.estimatedWpm} WPM',
                  style: const TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
                ),
                Text(
                  '~${(((item.currentChapter * 3500) / item.estimatedWpm) / 60).toStringAsFixed(1)} hrs',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
