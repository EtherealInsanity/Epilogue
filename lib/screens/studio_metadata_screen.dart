import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/epub_project.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';

class StudioMetadataScreen extends StatefulWidget {
  final EpubProject project;
  final VoidCallback onSave;

  const StudioMetadataScreen({
    super.key,
    required this.project,
    required this.onSave,
  });

  @override
  State<StudioMetadataScreen> createState() => _StudioMetadataScreenState();
}

class _StudioMetadataScreenState extends State<StudioMetadataScreen> {
  late EpubProject _project;
  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _identifierCtrl;
  late TextEditingController _languageCtrl;
  late TextEditingController _publisherCtrl;
  late TextEditingController _rightsCtrl;
  late TextEditingController _descriptionCtrl;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _titleCtrl = TextEditingController(text: _project.title);
    _authorCtrl = TextEditingController(text: _project.author);
    _identifierCtrl = TextEditingController(text: _project.identifier);
    _languageCtrl = TextEditingController(text: _project.language);
    _publisherCtrl = TextEditingController(text: _project.publisher);
    _rightsCtrl = TextEditingController(text: _project.rights);
    _descriptionCtrl = TextEditingController(text: _project.description);
    _coverPath = _project.coverImagePath;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _identifierCtrl.dispose();
    _languageCtrl.dispose();
    _publisherCtrl.dispose();
    _rightsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res != null && res.files.single.path != null) {
        setState(() {
          _coverPath = res.files.single.path!;
        });
      }
    } catch (_) {}
  }

  void _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _identifierCtrl.text = 'urn:uuid:$now';
    });
  }

  Future<void> _saveMetadata() async {
    final updated = _project.copyWith(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Untitled Book',
      author: _authorCtrl.text.trim().isNotEmpty ? _authorCtrl.text.trim() : 'Anonymous',
      identifier: _identifierCtrl.text.trim().isNotEmpty ? _identifierCtrl.text.trim() : 'urn:uuid:${DateTime.now().millisecondsSinceEpoch}',
      language: _languageCtrl.text.trim().isNotEmpty ? _languageCtrl.text.trim() : 'en',
      publisher: _publisherCtrl.text.trim(),
      rights: _rightsCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      coverImagePath: _coverPath,
      modifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await StudioProjectService.saveProject(updated);
    widget.onSave();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Metadata saved successfully!'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Book Metadata & Cover'),
        actions: [
          TextButton(
            onPressed: _saveMetadata,
            child: Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Cover Image Card
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 104,
                    decoration: BoxDecoration(
                      color: EpilogueTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EpilogueTheme.border),
                      image: _coverPath != null && File(_coverPath!).existsSync()
                          ? DecorationImage(
                              image: FileImage(File(_coverPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverPath == null || !File(_coverPath!).existsSync()
                        ? Center(child: Icon(Icons.add_photo_alternate_outlined, color: EpilogueTheme.cyanAccent, size: 30))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Book Cover Art',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recommended: 1600x2400 (1:1.5 ratio) JPEG or PNG for e-readers.',
                          style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.upload, size: 14),
                              label: const Text('CHOOSE', style: TextStyle(fontSize: 11)),
                              onPressed: _pickCoverImage,
                            ),
                            if (_coverPath != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() => _coverPath = null),
                                child: Text('REMOVE', style: TextStyle(color: EpilogueTheme.dangerAccent, fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Core Dublin Core Fields
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DUBLIN CORE METADATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: EpilogueTheme.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Book Title (dc:title) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _authorCtrl,
                    decoration: const InputDecoration(labelText: 'Author Name (dc:creator) *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _identifierCtrl,
                          decoration: const InputDecoration(labelText: 'Unique ID / ISBN (dc:identifier) *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Generate UUID',
                        icon: Icon(Icons.refresh, color: EpilogueTheme.cyanAccent),
                        onPressed: _generateUuid,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _languageCtrl,
                          decoration: const InputDecoration(labelText: 'Language Code (e.g. en, es, ja, ko)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _publisherCtrl,
                          decoration: const InputDecoration(labelText: 'Publisher Name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rightsCtrl,
                    decoration: const InputDecoration(labelText: 'Copyright Rights (e.g. All rights reserved)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Book Description / Synopsis (dc:description)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: EpilogueTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('SAVE METADATA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: _saveMetadata,
          ),
        ],
      ),
    );
  }
}
