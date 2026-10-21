import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects({bool force = false}) async {
    if (_projects.isEmpty) {
      setState(() => _isLoading = true);
    }
    final list = await StudioProjectService.loadProjects(forceReload: force);
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
                await _loadProjects(force: true);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudioEditorScreen(project: proj, onSave: () => _loadProjects(force: false)),
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
        await _loadProjects(force: true);
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
        await _loadProjects(force: true);
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

  Future<void> _duplicateProject(EpubProject project) async {
    final copy = await StudioProjectService.duplicateProject(project);
    await _loadProjects(force: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${project.title}" as "${copy.title}"'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  Future<void> _exportTxt(EpubProject project) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/Epilogue_Exports');
      if (!await exportDir.exists()) await exportDir.create(recursive: true);

      final cleanTitle = project.title.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
      final path = '${exportDir.path}/${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.txt';
      await StudioProjectService.exportToPlainText(project, path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported plain text to:\n$path'),
            backgroundColor: EpilogueTheme.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: EpilogueTheme.dangerAccent),
        );
      }
    }
  }

  Future<void> _exportMd(EpubProject project) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/Epilogue_Exports');
      if (!await exportDir.exists()) await exportDir.create(recursive: true);

      final cleanTitle = project.title.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
      final path = '${exportDir.path}/${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.md';
      await StudioProjectService.exportToMarkdown(project, path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported Markdown manuscript to:\n$path'),
            backgroundColor: EpilogueTheme.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: EpilogueTheme.dangerAccent),
        );
      }
    }
  }

  void _showExportOptions(EpubProject project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.output, color: EpilogueTheme.cyanAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Export "${project.title}"',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: EpilogueTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.verified, color: EpilogueTheme.cyanAccent),
                title: const Text('EPUB 3.3 / Linter Export', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Pre-flight validation, XHTML repair & direct .epub packaging', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudioLinterScreen(project: project)),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.text_snippet_outlined, color: EpilogueTheme.greenAccent),
                title: const Text('Plain Text Manuscript (.txt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Clean chapter-separated text file for backups & external notes', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportTxt(project);
                },
              ),
              ListTile(
                leading: Icon(Icons.description_outlined, color: EpilogueTheme.starGold),
                title: const Text('Markdown Manuscript (.md)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Structured headings (# Chapter), scene breaks & blockquotes', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportMd(project);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
              await _loadProjects(force: true);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedProjects = _searchQuery.isEmpty
        ? _projects
        : _projects
            .where((p) =>
                p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.author.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

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
                  onRefresh: () => _loadProjects(force: true),
                  color: EpilogueTheme.cyanAccent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      if (_projects.length > 2) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: EpilogueTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: EpilogueTheme.border),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search manuscripts by title or author...',
                              prefixIcon: Icon(Icons.search, size: 20, color: EpilogueTheme.textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                      ],
                      for (final proj in displayedProjects) ...[
                        _buildProjectCard(proj),
                        const SizedBox(height: 14),
                      ],
                    ],
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
              builder: (_) => StudioEditorScreen(
                project: project,
                onSave: () => _loadProjects(force: false),
              ),
            ),
          );
          _loadProjects(force: false);
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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: EpilogueTheme.textSecondary),
                    onSelected: (val) {
                      if (val == 'duplicate') _duplicateProject(project);
                      if (val == 'export') _showExportOptions(project);
                      if (val == 'delete') _showDeleteDialog(project);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Duplicate Book'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.output_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Export Formats (TXT, MD, EPUB)'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: EpilogueTheme.dangerAccent),
                            const SizedBox(width: 8),
                            Text('Delete Book', style: TextStyle(color: EpilogueTheme.dangerAccent)),
                          ],
                        ),
                      ),
                    ],
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
                        MaterialPageRoute(builder: (_) => StudioSpineScreen(project: project, onSave: () => _loadProjects(force: false))),
                      );
                      _loadProjects(force: false);
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('Metadata', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudioMetadataScreen(project: project, onSave: () => _loadProjects(force: false))),
                      );
                      _loadProjects(force: false);
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    icon: const Icon(Icons.output, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showExportOptions(project),
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
