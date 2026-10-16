import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book_info.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class DialogEditMetadata extends StatefulWidget {
  final BookInfo book;
  final StorageService storageService;
  final VoidCallback onUpdated;

  const DialogEditMetadata({
    super.key,
    required this.book,
    required this.storageService,
    required this.onUpdated,
  });

  @override
  State<DialogEditMetadata> createState() => _DialogEditMetadataState();
}

class _DialogEditMetadataState extends State<DialogEditMetadata> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _chaptersController;
  String? _currentCoverPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _chaptersController = TextEditingController(text: '${widget.book.totalChapters}');
    _currentCoverPath = widget.book.coverImagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _chaptersController.dispose();
    super.dispose();
  }

  Future<void> _pickNewCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final originalPath = result.files.single.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory('${appDir.path}/covers');
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        final ext = originalPath.split('.').last;
        final targetPath =
            '${coversDir.path}/${widget.book.id.hashCode}_custom_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await File(originalPath).copy(targetPath);

        setState(() {
          _currentCoverPath = targetPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick cover image: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : widget.book.title;
    final author = _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : widget.book.author;
    final chapters = int.tryParse(_chaptersController.text.trim()) ?? widget.book.totalChapters;

    final updated = widget.book.copyWith(
      title: title,
      author: author,
      totalChapters: chapters,
      coverImagePath: _currentCoverPath,
    );

    final books = widget.storageService.loadBooks();
    final index = books.indexWhere((b) => b.id == widget.book.id);
    if (index >= 0) {
      books[index] = updated;
    } else {
      books.add(updated);
    }
    await widget.storageService.saveBooks(books);

    setState(() => _isSaving = false);
    if (mounted) {
      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Book metadata updated successfully.'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidCover = _currentCoverPath != null && File(_currentCoverPath!).existsSync();

    return AlertDialog(
      backgroundColor: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: EpilogueTheme.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: EpilogueTheme.accent, size: 24),
          SizedBox(width: 8),
          Text(
            'Edit Metadata',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: EpilogueTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Preview & Replace button
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 130,
                    decoration: BoxDecoration(
                      color: EpilogueTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EpilogueTheme.borderStrong),
                      image: hasValidCover
                          ? DecorationImage(
                              image: FileImage(File(_currentCoverPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasValidCover
                        ? null
                        : const Center(
                            child: Icon(Icons.auto_stories, size: 36, color: EpilogueTheme.textMuted),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _pickNewCover,
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Change Cover Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: EpilogueTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Novel Title',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Author Field
            TextField(
              controller: _authorController,
              style: const TextStyle(color: EpilogueTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Author Name',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chapters Field
            TextField(
              controller: _chaptersController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: EpilogueTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Total Chapters',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: EpilogueTheme.accent,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
