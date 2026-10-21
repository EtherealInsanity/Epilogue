import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book_info.dart';
import '../screens/studio_editor_screen.dart';
import '../services/storage_service.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';
import 'dialog_edit_metadata.dart';

class BottomSheetBookDetail extends StatelessWidget {
  final BookInfo book;
  final StorageService storageService;
  final VoidCallback onOpenBook;
  final VoidCallback onUpdated;

  const BottomSheetBookDetail({
    super.key,
    required this.book,
    required this.storageService,
    required this.onOpenBook,
    required this.onUpdated,
  });

  Future<void> _editInStudio(BuildContext context) async {
    Navigator.pop(context);
    try {
      final proj = await StudioProjectService.importFromEpub(book.filePath);
      await StudioProjectService.saveProject(proj);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudioEditorScreen(project: proj, onSave: onUpdated),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load into Studio: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  void _showEditMetadataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => DialogEditMetadata(
        book: book,
        storageService: storageService,
        onUpdated: () {
          Navigator.pop(context);
          onUpdated();
        },
      ),
    );
  }

  void _confirmRemoveBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Remove from Library', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${book.title}" from your library? (The EPUB file on your device will remain safe).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              final books = storageService.loadBooks();
              books.removeWhere((b) => b.id == book.id);
              await storageService.saveBooks(books);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
              onUpdated();
            },
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.dangerAccent),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _showBatchCheckoffDialog(BuildContext context) {
    final controller = TextEditingController(
      text: book.totalChapters > 0 ? '${book.totalChapters}' : '100',
    );
    final wordsPerChController = TextEditingController(text: '2500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: Text(
          'Mark Past Chapters as Read',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: EpilogueTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set how many chapters you have already read elsewhere. Words and reading time will be credited to your reading status.',
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Up to Chapter #',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wordsPerChController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Average Words per Chapter',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final ch = int.tryParse(controller.text) ?? 1;
              final wpc = int.tryParse(wordsPerChController.text) ?? 2500;
              final targetChIndex = (ch - 1).clamp(0, book.totalChapters > 0 ? book.totalChapters - 1 : 9999);
              final totalAddedWords = ch * wpc;
              final totalAddedSeconds = (ch * 4 * 60);

              await storageService.updateBookProgress(
                bookId: book.id,
                chapterIndex: targetChIndex,
                progressPercent: book.totalChapters > 0 ? ((ch / book.totalChapters) * 100).clamp(0.0, 100.0) : 100.0,
              );
              await storageService.addReadingSessionTime(
                bookId: book.id,
                seconds: totalAddedSeconds,
                wordsRead: totalAddedWords,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
              onUpdated();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EpilogueTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = book.totalChapters > 0
        ? ((book.lastReadChapterIndex / book.totalChapters) * 100).clamp(0.0, 100.0)
        : book.lastReadProgressPercent;

    final hasValidCover = book.coverImagePath != null && File(book.coverImagePath!).existsSync();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EpilogueTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EpilogueTheme.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 65,
                height: 92,
                decoration: BoxDecoration(
                  color: EpilogueTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EpilogueTheme.borderStrong),
                  image: hasValidCover
                      ? DecorationImage(
                          image: FileImage(File(book.coverImagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasValidCover
                    ? null
                    : Center(
                        child: Icon(Icons.auto_stories, color: EpilogueTheme.accent, size: 30),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: EpilogueTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 13,
                        color: EpilogueTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ch. ${book.lastReadChapterIndex + 1}/${book.totalChapters > 0 ? book.totalChapters : "?"}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: EpilogueTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${progress.toStringAsFixed(0)}% Read',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary Read Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpenBook();
              },
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('READ NOVEL', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: EpilogueTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Edit in Studio Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editInStudio(context),
              icon: Icon(Icons.edit_note, size: 18, color: EpilogueTheme.cyanAccent),
              label: Text('EDIT IN STUDIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: EpilogueTheme.cyanAccent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: EpilogueTheme.cyanAccent),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditMetadataDialog(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('EDIT METADATA', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EpilogueTheme.textPrimary,
                    side: BorderSide(color: EpilogueTheme.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBatchCheckoffDialog(context),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('MARK CHAPTERS', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EpilogueTheme.accent,
                    side: BorderSide(color: EpilogueTheme.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Remove Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _confirmRemoveBook(context),
              icon: Icon(Icons.delete_outline, size: 16, color: EpilogueTheme.dangerAccent),
              label: Text('REMOVE FROM LIBRARY', style: TextStyle(color: EpilogueTheme.dangerAccent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
