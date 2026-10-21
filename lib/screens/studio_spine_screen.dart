import 'package:flutter/material.dart';
import '../models/epub_project.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';

class StudioSpineScreen extends StatefulWidget {
  final EpubProject project;
  final VoidCallback onSave;

  const StudioSpineScreen({
    super.key,
    required this.project,
    required this.onSave,
  });

  @override
  State<StudioSpineScreen> createState() => _StudioSpineScreenState();
}

class _StudioSpineScreenState extends State<StudioSpineScreen> {
  late List<ProjectChapter> _chapters;
  late EpubProject _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _chapters = List<ProjectChapter>.from(widget.project.chapters);
  }

  Future<void> _commitChanges() async {
    final updated = _project.copyWith(
      chapters: _chapters,
      modifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await StudioProjectService.saveProject(updated);
    setState(() => _project = updated);
    widget.onSave();
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);

      // Re-assign order indices
      for (int i = 0; i < _chapters.length; i++) {
        _chapters[i] = _chapters[i].copyWith(order: i);
      }
    });
    _commitChanges();
  }

  void _addNewChapter() {
    final count = _chapters.length + 1;
    final newCh = ProjectChapter(
      id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Chapter $count: New Chapter',
      contentHtml: '<p>Start writing chapter $count here...</p>',
      contentMarkdown: '# Chapter $count: New Chapter\n\nStart writing chapter $count here...',
      order: _chapters.length,
    );

    setState(() {
      _chapters.add(newCh);
    });
    _commitChanges();
  }

  void _renameChapter(int index) {
    final ch = _chapters[index];
    final ctrl = TextEditingController(text: ch.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Rename Chapter'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Chapter Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
            onPressed: () {
              Navigator.pop(ctx);
              final newTitle = ctrl.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _chapters[index] = ch.copyWith(title: newTitle);
                });
                _commitChanges();
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _deleteChapter(int index) {
    if (_chapters.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A book must contain at least one chapter.'),
          backgroundColor: EpilogueTheme.dangerAccent,
        ),
      );
      return;
    }

    final ch = _chapters[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Delete Chapter?'),
        content: Text('Are you sure you want to delete "${ch.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.dangerAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _chapters.removeAt(index);
                for (int i = 0; i < _chapters.length; i++) {
                  _chapters[i] = _chapters[i].copyWith(order: i);
                }
              });
              _commitChanges();
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _duplicateChapter(int index) {
    final original = _chapters[index];
    final copy = ProjectChapter(
      id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
      title: '${original.title} (Copy)',
      contentHtml: original.contentHtml,
      contentMarkdown: original.contentMarkdown,
      order: index + 1,
    );

    setState(() {
      _chapters.insert(index + 1, copy);
      for (int i = 0; i < _chapters.length; i++) {
        _chapters[i] = _chapters[i].copyWith(order: i);
      }
    });
    _commitChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Spine & Table of Contents'),
        actions: [
          IconButton(
            tooltip: 'Add Chapter',
            icon: Icon(Icons.add, color: EpilogueTheme.cyanAccent),
            onPressed: _addNewChapter,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EpilogueTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ADD CHAPTER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        onPressed: _addNewChapter,
      ),
      body: _chapters.isEmpty
          ? const Center(child: Text('No chapters in spine.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: _chapters.length,
              onReorderItem: _onReorderItem,
              itemBuilder: (ctx, idx) {
                final ch = _chapters[idx];
                return Card(
                  key: ValueKey(ch.id),
                  color: EpilogueTheme.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: EpilogueTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: EpilogueTheme.surfaceElevated,
                      foregroundColor: EpilogueTheme.cyanAccent,
                      radius: 16,
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      ch.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: EpilogueTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${ch.wordCount} words',
                      style: TextStyle(fontSize: 11, color: EpilogueTheme.textMuted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _renameChapter(idx),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (val) {
                            if (val == 'dup') _duplicateChapter(idx);
                            if (val == 'del') _deleteChapter(idx);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'dup',
                              child: Row(
                                children: [
                                  Icon(Icons.copy, size: 16),
                                  SizedBox(width: 8),
                                  Text('Duplicate Chapter'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'del',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: EpilogueTheme.dangerAccent),
                                  const SizedBox(width: 8),
                                  Text('Delete Chapter', style: TextStyle(color: EpilogueTheme.dangerAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.drag_handle, color: EpilogueTheme.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
