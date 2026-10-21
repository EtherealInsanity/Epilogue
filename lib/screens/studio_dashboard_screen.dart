import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/epub_project.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';
import 'studio_editor_screen.dart';
import 'studio_linter_screen.dart';
import 'studio_metadata_screen.dart';
import 'studio_spine_screen.dart';

class StudioDashboardScreen extends StatefulWidget {
  const StudioDashboardScreen({super.key});

  @override
  State<StudioDashboardScreen> createState() => _StudioDashboardScreenState();
}

class _StudioDashboardScreenState extends State<StudioDashboardScreen> {
  List<EpubProject> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final list = await StudioProjectService.loadProjects();
    if (mounted) {
      setState(() {
        _projects = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewBook() async {
    final titleCtrl = TextEditingController(text: 'My New Book');
    final authorCtrl = TextEditingController(text: 'Author Name');
    StudioTemplate selectedTemplate = StudioTemplate.novel;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: EpilogueTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: EpilogueTheme.border),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_stories, color: EpilogueTheme.cyanAccent),
              const SizedBox(width: 10),
              const Text('Create New Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Book Title', hintText: 'Enter title...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorCtrl,
                  decoration: const InputDecoration(labelText: 'Author Name', hintText: 'Your name or pseudonym...'),
                ),
                const SizedBox(height: 16),
                const Text('Choose Genre Template:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                RadioGroup<StudioTemplate>(
                  groupValue: selectedTemplate,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedTemplate = val);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<StudioTemplate>(
                        title: const Text('Classic Novel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Literary prose with drop caps, scene dividers, and indented body.', style: TextStyle(fontSize: 11)),
                        value: StudioTemplate.novel,
                        activeColor: EpilogueTheme.cyanAccent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<StudioTemplate>(
                        title: const Text('Light Novel / Fantasy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Star Stream dialogue status boxes, constellation shouts, and stat cards.', style: TextStyle(fontSize: 11)),
                        value: StudioTemplate.lightNovel,
                        activeColor: EpilogueTheme.cyanAccent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<StudioTemplate>(
                        title: const Text('Non-Fiction / Academic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Hierarchical headings (H1-H4), callouts, and structured footnotes.', style: TextStyle(fontSize: 11)),
                        value: StudioTemplate.nonFiction,
                        activeColor: EpilogueTheme.cyanAccent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
              onPressed: () async {
                Navigator.pop(ctx);
                final proj = await StudioProjectService.createFromTemplate(
                  template: selectedTemplate,
                  title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Untitled Book',
                  author: authorCtrl.text.trim().isNotEmpty ? authorCtrl.text.trim() : 'Anonymous',
                );
                await StudioProjectService.saveProject(proj);
                await _loadProjects();
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudioEditorScreen(project: proj, onSave: _loadProjects),
                    ),
                  );
                }
              },
              child: const Text('CREATE BOOK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importExistingEpub() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        setState(() => _isLoading = true);
        final proj = await StudioProjectService.importFromEpub(path);
        await StudioProjectService.saveProject(proj);
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported "${proj.title}" successfully into Studio!'),
              backgroundColor: EpilogueTheme.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import EPUB: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  Future<void> _importMarkdownOrText() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
      );
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        final content = await File(path).readAsString();
        final filename = path.split('/').last.replaceAll(RegExp(r'\.(txt|md)$'), '');
        final proj = StudioProjectService.importFromTextOrMarkdown(
          content,
          title: filename,
        );
        await StudioProjectService.saveProject(proj);
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported "${proj.title}" with ${proj.chapters.length} chapters!'),
              backgroundColor: EpilogueTheme.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import text: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(EpubProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Delete Book Project?'),
        content: Text('Are you sure you want to delete "${project.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.dangerAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await StudioProjectService.deleteProject(project.id);
              await _loadProjects();
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Epilogue Studio'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'import_epub') _importExistingEpub();
              if (val == 'import_txt') _importMarkdownOrText();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'import_epub',
                child: Row(
                  children: [
                    Icon(Icons.file_open_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Import Existing .epub'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_txt',
                child: Row(
                  children: [
                    Icon(Icons.text_snippet_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Import .txt / .md Story'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EpilogueTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('NEW BOOK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        onPressed: _createNewBook,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: EpilogueTheme.cyanAccent))
          : _projects.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  color: EpilogueTheme.cyanAccent,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (ctx, idx) => _buildProjectCard(_projects[idx]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: EpilogueTheme.cyanAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_note, size: 54, color: EpilogueTheme.cyanAccent),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Author Studio is Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: EpilogueTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Craft retail-ready EPUB 3.3 books from scratch with tri-mode editing (WYSIWYG, Markdown, and Source Inspector) or import existing novels.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('IMPORT EPUB'),
                  onPressed: _importExistingEpub,
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('NEW BOOK'),
                  onPressed: _createNewBook,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(EpubProject project) {
    return Card(
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudioEditorScreen(project: project, onSave: _loadProjects),
            ),
          );
          _loadProjects();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Thumbnail
                  Container(
                    width: 52,
                    height: 72,
                    decoration: BoxDecoration(
                      color: EpilogueTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EpilogueTheme.border),
                      image: project.coverImagePath != null && File(project.coverImagePath!).existsSync()
                          ? DecorationImage(
                              image: FileImage(File(project.coverImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: project.coverImagePath == null || !File(project.coverImagePath!).existsSync()
                        ? Center(child: Icon(Icons.book, color: EpilogueTheme.cyanAccent, size: 28))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: EpilogueTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${project.author}',
                          style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: EpilogueTheme.cyanAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${project.chapters.length} Chapters',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${project.totalWords} words',
                              style: TextStyle(fontSize: 11, color: EpilogueTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: EpilogueTheme.dangerAccent),
                    onPressed: () => _showDeleteDialog(project),
                  ),
                ],
              ),
              Divider(color: EpilogueTheme.border, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: const Text('Spine / TOC', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudioSpineScreen(project: project, onSave: _loadProjects)),
                      );
                      _loadProjects();
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('Metadata', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudioMetadataScreen(project: project, onSave: _loadProjects)),
                      );
                      _loadProjects();
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudioLinterScreen(project: project)),
                      );
                      _loadProjects();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
