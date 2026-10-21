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
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _initActiveChapterControllers();
  }

  void _initActiveChapterControllers() {
    if (_project.chapters.isEmpty) {
      _titleCtrl = TextEditingController(text: 'Chapter 1');
      _contentCtrl = TextEditingController(text: '');
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
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _onContentChanged(String val) {
    _hasUnsavedChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), _saveCurrentDraft);
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
        // Simple MD-to-HTML conversion
        html = _convertMarkdownToHtml(md);
        break;
    }

    final updatedCh = currentCh.copyWith(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Chapter ${idx + 1}',
      contentHtml: html,
      contentMarkdown: md,
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
        // Handle bold & italic
        var formatted = trimmed
            .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m[1]}</b>')
            .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => '<i>${m[1]}</i>');
        out.add('<p>$formatted</p>');
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

  @override
  Widget build(BuildContext context) {
    final ch = _project.chapters.isNotEmpty
        ? _project.chapters[_activeChapterIndex.clamp(0, _project.chapters.length - 1)]
        : null;

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
            tooltip: 'Live Reader Preview',
            icon: Icon(Icons.visibility_outlined, color: EpilogueTheme.cyanAccent),
            onPressed: _showLivePreview,
          ),
          IconButton(
            tooltip: 'Spine & TOC',
            icon: const Icon(Icons.format_list_bulleted),
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
            ),
            onPressed: _saveCurrentDraft,
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Selector Ribbon
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
                if (ch != null)
                  Text(
                    '${ch.wordCount} words',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.textMuted),
                  ),
              ],
            ),
          ),

          // Chapter Title Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          _toolbarAction('[Lore]', () {
            _insertTag('<div class="star-stream-dialogue">[', ']</div>');
          }),
          _toolbarAction('Footnote', () {
            _insertTag('<aside epub:type="footnote">', '</aside>');
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
