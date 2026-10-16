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

  @override
  void dispose() {
    _searchController.dispose();
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
      decoration: const BoxDecoration(
        color: EpilogueTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const Row(
            children: [
              Icon(Icons.list_alt, color: EpilogueTheme.accent, size: 20),
              SizedBox(width: 8),
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
            style: const TextStyle(color: EpilogueTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Filter chapters...',
              hintStyle: const TextStyle(color: EpilogueTheme.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 18, color: EpilogueTheme.textSecondary),
              filled: true,
              fillColor: EpilogueTheme.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EpilogueTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: EpilogueTheme.border),
              itemBuilder: (context, index) {
                final ch = filtered[index];
                final isCurrent = ch.index == widget.currentChapterIndex;

                return ListTile(
                  tileColor: isCurrent ? const Color(0xFFE0F2FE) : Colors.transparent,
                  leading: Text(
                    '${ch.index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
                    ),
                  ),
                  title: Text(
                    ch.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? EpilogueTheme.cyanAccent : EpilogueTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isCurrent ? const Icon(Icons.bookmark, color: EpilogueTheme.cyanAccent, size: 18) : null,
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
