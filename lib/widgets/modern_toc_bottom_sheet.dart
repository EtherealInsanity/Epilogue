import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../theme/epilogue_theme.dart';

class ModernTocBottomSheet extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;

  const ModernTocBottomSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  State<ModernTocBottomSheet> createState() => _ModernTocBottomSheetState();
}

class _ModernTocBottomSheetState extends State<ModernTocBottomSheet> {
  String _query = '';
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  void _scrollToCurrentChapter() {
    if (!_scrollController.hasClients) return;
    final targetIndex = widget.chapters.indexWhere((ch) => ch.index == widget.currentChapterIndex);
    if (targetIndex > 0) {
      // Approximate 56px per tile + divider, offset to give some breathing room
      final targetOffset = (targetIndex * 56.0 - 60.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.chapters.where((ch) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return ch.title.toLowerCase().contains(q) || '${ch.index + 1}'.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: EpilogueTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: EpilogueTheme.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.list_alt, color: EpilogueTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Table of Contents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EpilogueTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _query = val.trim()),
            style: TextStyle(color: EpilogueTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Filter chapters...',
              hintStyle: TextStyle(color: EpilogueTheme.textSecondary),
              prefixIcon: Icon(Icons.search, size: 18, color: EpilogueTheme.textSecondary),
              filled: true,
              fillColor: EpilogueTheme.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EpilogueTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: EpilogueTheme.border),
              itemBuilder: (context, index) {
                final ch = filtered[index];
                final isCurrent = ch.index == widget.currentChapterIndex;

                return ListTile(
                  tileColor: isCurrent ? EpilogueTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: Text(
                    '${ch.index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? EpilogueTheme.accent : EpilogueTheme.textSecondary,
                    ),
                  ),
                  title: Text(
                    ch.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? EpilogueTheme.accent : EpilogueTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isCurrent ? Icon(Icons.bookmark, color: EpilogueTheme.accent, size: 18) : null,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onChapterSelected(ch.index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
