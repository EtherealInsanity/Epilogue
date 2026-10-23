import 'dart:async';
import 'package:flutter/material.dart';
import '../models/epub_project.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';
import 'studio_spine_screen.dart';

enum EditorMode {
  wysiwyg,
  markdown,
  sourceHtml,
}

class StudioEditorScreen extends StatefulWidget {
  final EpubProject project;
  final VoidCallback onSave;

  const StudioEditorScreen({
    super.key,
    required this.project,
    required this.onSave,
  });

  @override
  State<StudioEditorScreen> createState() => _StudioEditorScreenState();
}

class _StudioEditorScreenState extends State<StudioEditorScreen> {
  late EpubProject _project;
  int _activeChapterIndex = 0;
  EditorMode _editorMode = EditorMode.wysiwyg;

  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _controllersInitialized = false;
  Timer? _autoSaveTimer;
  Timer? _historyDebounceTimer;
  bool _hasUnsavedChanges = false;

  // Undo / Redo history
  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];
  bool _isPerformingUndoRedo = false;

  // Find & Replace
  bool _isFindReplaceVisible = false;
  final TextEditingController _findCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  bool _isCaseSensitive = false;
  int _currentMatchIndex = -1;
  List<int> _matchOffsets = [];

  // Live Stats HUD toggle
  bool _showStatsHud = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _initActiveChapterControllers();
  }

  void _initActiveChapterControllers() {
    if (_controllersInitialized) {
      _titleCtrl.dispose();
      _contentCtrl.dispose();
    }
    _controllersInitialized = true;

    if (_project.chapters.isEmpty) {
      _titleCtrl = TextEditingController(text: 'Chapter 1');
      _contentCtrl = TextEditingController(text: '');
      _undoStack.clear();
      _redoStack.clear();
      return;
    }

    final ch = _project.chapters[_activeChapterIndex.clamp(0, _project.chapters.length - 1)];
    _titleCtrl = TextEditingController(text: ch.title);

    switch (_editorMode) {
      case EditorMode.wysiwyg:
      case EditorMode.sourceHtml:
        _contentCtrl = TextEditingController(text: ch.contentHtml);
        break;
      case EditorMode.markdown:
        _contentCtrl = TextEditingController(
          text: ch.contentMarkdown.isNotEmpty ? ch.contentMarkdown : ch.contentHtml,
        );
        break;
    }

    _undoStack.clear();
    _redoStack.clear();
    _undoStack.add(_contentCtrl.value);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _historyDebounceTimer?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }

  void _recordHistorySnapshot() {
    if (_isPerformingUndoRedo) return;
    if (_undoStack.isEmpty || _undoStack.last.text != _contentCtrl.text) {
      if (_undoStack.length >= 35) {
        _undoStack.removeAt(0);
      }
      _undoStack.add(_contentCtrl.value);
      _redoStack.clear();
    }
  }

  void _undo() {
    if (_undoStack.length <= 1) return;
    _isPerformingUndoRedo = true;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final previous = _undoStack.last;
    _contentCtrl.value = previous;
    _isPerformingUndoRedo = false;
    _onContentChanged(previous.text);
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _isPerformingUndoRedo = true;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _contentCtrl.value = next;
    _isPerformingUndoRedo = false;
    _onContentChanged(next.text);
    setState(() {});
  }

  void _onContentChanged(String val) {
    _hasUnsavedChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), _saveCurrentDraft);

    _historyDebounceTimer?.cancel();
    _historyDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _recordHistorySnapshot();
    });

    if (_isFindReplaceVisible && _findCtrl.text.isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _saveCurrentDraft() async {
    if (_project.chapters.isEmpty) return;

    final idx = _activeChapterIndex.clamp(0, _project.chapters.length - 1);
    final currentCh = _project.chapters[idx];

    String html = currentCh.contentHtml;
    String md = currentCh.contentMarkdown;

    switch (_editorMode) {
      case EditorMode.wysiwyg:
      case EditorMode.sourceHtml:
        html = _contentCtrl.text;
        break;
      case EditorMode.markdown:
        md = _contentCtrl.text;
        html = _convertMarkdownToHtml(md);
        break;
    }

    final wc = ProjectChapter.computeWordCount(html);

    final updatedCh = currentCh.copyWith(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Chapter ${idx + 1}',
      contentHtml: html,
      contentMarkdown: md,
      cachedWordCount: wc,
    );

    final updatedChapters = List<ProjectChapter>.from(_project.chapters);
    updatedChapters[idx] = updatedCh;

    final updatedProj = _project.copyWith(chapters: updatedChapters);
    await StudioProjectService.saveProject(updatedProj);

    if (mounted) {
      setState(() {
        _project = updatedProj;
        _hasUnsavedChanges = false;
      });
      widget.onSave();
    }
  }

  String _convertMarkdownToHtml(String markdown) {
    final lines = markdown.split('\n');
    final out = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        out.add('<h1 class="chapter-title">${trimmed.substring(2)}</h1>');
      } else if (trimmed.startsWith('## ')) {
        out.add('<h2>${trimmed.substring(3)}</h2>');
      } else if (trimmed.startsWith('### ')) {
        out.add('<h3>${trimmed.substring(4)}</h3>');
      } else if (trimmed == '* * *' || trimmed == '---') {
        out.add('<hr class="scene-break"/>');
      } else if (trimmed.startsWith('> ')) {
        out.add('<blockquote>${trimmed.substring(2)}</blockquote>');
      } else if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        out.add('<div class="star-stream-dialogue">$trimmed</div>');
      } else if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('<p') || trimmed.startsWith('<div') || trimmed.startsWith('<h') || trimmed.startsWith('<blockquote') || trimmed.startsWith('<hr')) {
          out.add(trimmed);
        } else {
          var formatted = trimmed
              .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m[1]}</b>')
              .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => '<i>${m[1]}</i>')
              .replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => '<del>${m[1]}</del>')
              .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<code>${m[1]}</code>');
          out.add('<p>$formatted</p>');
        }
      }
    }

    return out.join('\n');
  }

  void _switchEditorMode(EditorMode mode) {
    if (_editorMode == mode) return;
    _saveCurrentDraft();

    setState(() {
      _editorMode = mode;
      _initActiveChapterControllers();
    });
  }

  void _insertTag(String prefix, String suffix) {
    _recordHistorySnapshot();
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText = text.substring(start, end);

    final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length + selectedText.length),
    );
    _onContentChanged(newText);
    _recordHistorySnapshot();
    setState(() {});
  }

  // Find & Replace Engine
  void _performSearch() {
    final query = _findCtrl.text;
    final text = _contentCtrl.text;
    if (query.isEmpty || text.isEmpty) {
      setState(() {
        _matchOffsets = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final offsets = <int>[];
    final pattern = _isCaseSensitive ? query : query.toLowerCase();
    final source = _isCaseSensitive ? text : text.toLowerCase();

    int start = 0;
    while (true) {
      final idx = source.indexOf(pattern, start);
      if (idx == -1) break;
      offsets.add(idx);
      start = idx + query.length;
    }

    setState(() {
      _matchOffsets = offsets;
      if (offsets.isEmpty) {
        _currentMatchIndex = -1;
      } else if (_currentMatchIndex < 0 || _currentMatchIndex >= offsets.length) {
        _currentMatchIndex = 0;
        _highlightMatch(0);
      }
    });
  }

  void _nextMatch() {
    if (_matchOffsets.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchOffsets.length;
    });
    _highlightMatch(_currentMatchIndex);
  }

  void _prevMatch() {
    if (_matchOffsets.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchOffsets.length) % _matchOffsets.length;
    });
    _highlightMatch(_currentMatchIndex);
  }

  void _highlightMatch(int matchIdx) {
    if (matchIdx < 0 || matchIdx >= _matchOffsets.length) return;
    final start = _matchOffsets[matchIdx];
    final length = _findCtrl.text.length;
    _contentCtrl.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + length,
    );
  }

  void _replaceCurrent() {
    if (_matchOffsets.isEmpty || _currentMatchIndex < 0 || _currentMatchIndex >= _matchOffsets.length) return;
    final start = _matchOffsets[_currentMatchIndex];
    final length = _findCtrl.text.length;
    final replacement = _replaceCtrl.text;

    _recordHistorySnapshot();
    final text = _contentCtrl.text;
    final updated = text.replaceRange(start, start + length, replacement);
    _contentCtrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _onContentChanged(updated);
    _performSearch();
  }

  void _replaceAll() {
    if (_matchOffsets.isEmpty) return;
    final query = _findCtrl.text;
    final replacement = _replaceCtrl.text;
    final text = _contentCtrl.text;
    final count = _matchOffsets.length;

    _recordHistorySnapshot();
    String updated;
    if (_isCaseSensitive) {
      updated = text.replaceAll(query, replacement);
    } else {
      updated = text.replaceAll(RegExp(RegExp.escape(query), caseSensitive: false), replacement);
    }

    _contentCtrl.text = updated;
    _onContentChanged(updated);
    _performSearch();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replaced $count occurrences!'),
        backgroundColor: EpilogueTheme.accent,
      ),
    );
  }

  void _openCustomCssEditor() {
    final cssCtrl = TextEditingController(text: _project.customCss);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: EpilogueTheme.cyanAccent),
                const SizedBox(width: 8),
                Text(
                  'Book Stylesheet (CSS)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: EpilogueTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Custom CSS applied during EPUB rendering and reader export.',
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: EpilogueTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EpilogueTheme.border),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: cssCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  hintText: '/* Add custom CSS rules here */\n.chapter-title { font-family: serif; }',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final updated = _project.copyWith(customCss: cssCtrl.text);
                    await StudioProjectService.saveProject(updated);
                    setState(() => _project = updated);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Custom CSS saved!'),
                          backgroundColor: EpilogueTheme.greenAccent,
                        ),
                      );
                    }
                  },
                  child: const Text('SAVE CSS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLivePreview() {
    _saveCurrentDraft();
    final idx = _activeChapterIndex.clamp(0, _project.chapters.length - 1);
    final ch = _project.chapters[idx];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpilogueTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview, color: EpilogueTheme.cyanAccent),
                  const SizedBox(width: 8),
                  Text(
                    ch.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: EpilogueTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: EpilogueTheme.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      ch.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: EpilogueTheme.textPrimary,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ch.contentHtml.replaceAll(RegExp(r'<[^>]*>'), '\n\n').trim(),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        fontFamily: 'serif',
                        color: EpilogueTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Live Stats calculations
  int get _wordCount {
    final clean = _contentCtrl.text.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    if (clean.isEmpty) return 0;
    return clean.split(RegExp(r'\s+')).length;
  }

  int get _charCount => _contentCtrl.text.length;

  int get _paragraphCount {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;
  }

  int get _readingMinutes {
    final words = _wordCount;
    return (words / 220).ceil().clamp(1, 9999);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _activeChapterIndex,
            dropdownColor: EpilogueTheme.surface,
            icon: Icon(Icons.arrow_drop_down, color: EpilogueTheme.cyanAccent),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: EpilogueTheme.textPrimary,
            ),
            items: List.generate(_project.chapters.length, (idx) {
              final c = _project.chapters[idx];
              return DropdownMenuItem<int>(
                value: idx,
                child: Text(
                  c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            onChanged: (idx) {
              if (idx != null) {
                _saveCurrentDraft();
                setState(() {
                  _activeChapterIndex = idx;
                  _initActiveChapterControllers();
                });
              }
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo, size: 20),
            onPressed: _undoStack.length > 1 ? _undo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo, size: 20),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            tooltip: 'Find & Replace',
            icon: Icon(
              Icons.search,
              color: _isFindReplaceVisible ? EpilogueTheme.cyanAccent : null,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isFindReplaceVisible = !_isFindReplaceVisible;
                if (_isFindReplaceVisible) {
                  _performSearch();
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Custom CSS',
            icon: const Icon(Icons.palette_outlined, size: 20),
            onPressed: _openCustomCssEditor,
          ),
          IconButton(
            tooltip: 'Live Reader Preview',
            icon: Icon(Icons.visibility_outlined, color: EpilogueTheme.cyanAccent, size: 20),
            onPressed: _showLivePreview,
          ),
          IconButton(
            tooltip: 'Spine & TOC',
            icon: const Icon(Icons.format_list_bulleted, size: 20),
            onPressed: () async {
              _saveCurrentDraft();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudioSpineScreen(
                    project: _project,
                    onSave: () async {
                      final updated = await StudioProjectService.loadProjects();
                      final match = updated.firstWhere(
                        (p) => p.id == _project.id,
                        orElse: () => _project,
                      );
                      setState(() {
                        _project = match;
                        _activeChapterIndex = _activeChapterIndex.clamp(0, _project.chapters.length - 1);
                        _initActiveChapterControllers();
                      });
                      widget.onSave();
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Save Draft',
            icon: Icon(
              _hasUnsavedChanges ? Icons.save : Icons.check_circle_outline,
              color: _hasUnsavedChanges ? EpilogueTheme.cyanAccent : EpilogueTheme.greenAccent,
              size: 20,
            ),
            onPressed: _saveCurrentDraft,
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Selector Ribbon & Stats Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: EpilogueTheme.surfaceElevated,
            child: Row(
              children: [
                _buildModePill(EditorMode.wysiwyg, 'Visual WYSIWYG', Icons.auto_awesome),
                const SizedBox(width: 8),
                _buildModePill(EditorMode.markdown, 'Markdown', Icons.text_fields),
                const SizedBox(width: 8),
                _buildModePill(EditorMode.sourceHtml, 'Source (XHTML)', Icons.code),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _showStatsHud = !_showStatsHud),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _showStatsHud ? EpilogueTheme.cyanAccent.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined, size: 14, color: EpilogueTheme.cyanAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$_wordCount words',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Stats HUD
          if (_showStatsHud) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: EpilogueTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Words', '$_wordCount'),
                  _buildStatItem('Characters', '$_charCount'),
                  _buildStatItem('Paragraphs', '$_paragraphCount'),
                  _buildStatItem('Est. Read Time', '~$_readingMinutes min'),
                ],
              ),
            ),
            Divider(color: EpilogueTheme.border, height: 1),
          ],

          // Toggleable Find & Replace Ribbon
          if (_isFindReplaceVisible) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: EpilogueTheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _findCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Find in chapter...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => _performSearch(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _matchOffsets.isEmpty
                            ? '0/0'
                            : '${_currentMatchIndex + 1}/${_matchOffsets.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        onPressed: _prevMatch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        onPressed: _nextMatch,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.text_format,
                          size: 16,
                          color: _isCaseSensitive ? EpilogueTheme.cyanAccent : EpilogueTheme.textMuted,
                        ),
                        tooltip: 'Match Case',
                        onPressed: () {
                          setState(() => _isCaseSensitive = !_isCaseSensitive);
                          _performSearch();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _replaceCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Replace with...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(60, 34),
                        ),
                        onPressed: _replaceCurrent,
                        child: const Text('Replace', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: EpilogueTheme.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(70, 34),
                        ),
                        onPressed: _replaceAll,
                        child: const Text('All', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: EpilogueTheme.border, height: 1),
          ],

          // Chapter Title Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _titleCtrl,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: EpilogueTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Chapter Title...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onContentChanged,
            ),
          ),
          Divider(color: EpilogueTheme.border, height: 1),

          // Content Editor Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: _editorMode == EditorMode.sourceHtml ? 13 : 15,
                  fontFamily: _editorMode == EditorMode.sourceHtml ? 'monospace' : 'serif',
                  height: 1.6,
                  color: EpilogueTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: _editorMode == EditorMode.sourceHtml
                      ? '<p>Enter valid XHTML markup...</p>'
                      : 'Write your story here...',
                  border: InputBorder.none,
                ),
                onChanged: _onContentChanged,
              ),
            ),
          ),

          // Sticky Formatting Ribbon above keyboard
          _buildFormattingToolbar(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(fontSize: 10, color: EpilogueTheme.textSecondary)),
      ],
    );
  }

  Widget _buildModePill(EditorMode mode, String label, IconData icon) {
    final isSelected = _editorMode == mode;
    return InkWell(
      onTap: () => _switchEditorMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? EpilogueTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : EpilogueTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : EpilogueTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: EpilogueTheme.surface,
        border: Border(top: BorderSide(color: EpilogueTheme.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _toolbarAction('H1', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('# ', '\n');
            } else {
              _insertTag('<h1>', '</h1>');
            }
          }),
          _toolbarAction('H2', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('## ', '\n');
            } else {
              _insertTag('<h2>', '</h2>');
            }
          }),
          _toolbarAction('H3', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('### ', '\n');
            } else {
              _insertTag('<h3>', '</h3>');
            }
          }),
          _toolbarAction('B', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('**', '**');
            } else {
              _insertTag('<b>', '</b>');
            }
          }),
          _toolbarAction('I', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('*', '*');
            } else {
              _insertTag('<i>', '</i>');
            }
          }),
          _toolbarAction('U', () {
            _insertTag('<u>', '</u>');
          }),
          _toolbarAction('S', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('~~', '~~');
            } else {
              _insertTag('<del>', '</del>');
            }
          }),
          _toolbarAction('Code', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('`', '`');
            } else {
              _insertTag('<code>', '</code>');
            }
          }),
          _toolbarAction('Highlight', () {
            _insertTag('<mark>', '</mark>');
          }),
          _toolbarAction('Drop Cap', () {
            _insertTag('<span class="drop-cap">', '</span>');
          }),
          _toolbarAction('Divider', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('\n* * *\n', '');
            } else {
              _insertTag('\n<hr class="scene-break"/>\n', '');
            }
          }),
          _toolbarAction('Quote', () {
            if (_editorMode == EditorMode.markdown) {
              _insertTag('> ', '\n');
            } else {
              _insertTag('<blockquote>', '</blockquote>');
            }
          }),
          _toolbarAction('Center', () {
            _insertTag('<p style="text-align: center;">', '</p>');
          }),
          _toolbarAction('[Lore]', () {
            _insertTag('<div class="star-stream-dialogue">[', ']</div>');
          }),
          _toolbarAction('Footnote', () {
            _insertTag('<aside epub:type="footnote">', '</aside>');
          }),
          _toolbarAction('Sub', () {
            _insertTag('<sub>', '</sub>');
          }),
          _toolbarAction('Super', () {
            _insertTag('<sup>', '</sup>');
          }),
        ],
      ),
    );
  }

  Widget _toolbarAction(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: EpilogueTheme.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: EpilogueTheme.surfaceElevated,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: EpilogueTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
