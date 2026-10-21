import 'package:flutter/material.dart';
import '../models/book_highlight.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class DialogCreateHighlight extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final String selectedText;
  final StorageService storageService;
  final VoidCallback onSaved;

  const DialogCreateHighlight({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.selectedText,
    required this.storageService,
    required this.onSaved,
  });

  @override
  State<DialogCreateHighlight> createState() => _DialogCreateHighlightState();
}

class _DialogCreateHighlightState extends State<DialogCreateHighlight> {
  String _selectedColor = '#06B6D4'; // Dokja Cyan
  final _noteController = TextEditingController();

  static const List<Map<String, dynamic>> _colors = [
    {'hex': '#06B6D4', 'name': 'Cyan (Dokja)', 'color': Color(0xFF06B6D4)},
    {'hex': '#F59E0B', 'name': 'Gold (Constellation)', 'color': Color(0xFFF59E0B)},
    {'hex': '#EF4444', 'name': 'Crimson (Flame)', 'color': Color(0xFFEF4444)},
    {'hex': '#10B981', 'name': 'Emerald (Peace)', 'color': Color(0xFF10B981)},
    {'hex': '#8B5CF6', 'name': 'Violet (Abyss)', 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final highlight = BookHighlight(
      id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapterIndex: widget.chapterIndex,
      chapterTitle: widget.chapterTitle,
      selectedText: widget.selectedText.trim(),
      note: _noteController.text.trim(),
      colorHex: _selectedColor,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await widget.storageService.saveHighlight(highlight);
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quote highlighted & added to Scenarios Archives.'),
          backgroundColor: EpilogueTheme.cyanAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      title: Row(
        children: [
          Icon(Icons.format_quote, color: EpilogueTheme.cyanAccent, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Highlight & Annotate',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quote Preview Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(int.parse(_selectedColor.replaceFirst('#', '0x33'))),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')))),
              ),
              child: Text(
                '“${widget.selectedText}”',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: EpilogueTheme.textPrimary),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 14),

            // Color Palette Selector
            Text(
              'HIGHLIGHT COLOR',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: EpilogueTheme.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in _colors) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = item['hex']),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == item['hex'] ? Colors.black : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          if (_selectedColor == item['hex'])
                            BoxShadow(
                              color: (item['color'] as Color).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: _selectedColor == item['hex']
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Note Input
            Text(
              'ADD A NOTE / REACTION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: EpilogueTheme.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(color: EpilogueTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Write your thoughts, constellation reaction, or theory...',
                hintStyle: TextStyle(color: EpilogueTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: EpilogueTheme.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
          child: const Text('SAVE HIGHLIGHT'),
        ),
      ],
    );
  }
}
