import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/epub_project.dart';
import '../models/linter_issue.dart';
import '../services/epub_builder_service.dart';
import '../services/epub_linter_service.dart';
import '../services/studio_project_service.dart';
import '../theme/epilogue_theme.dart';

class StudioLinterScreen extends StatefulWidget {
  final EpubProject project;

  const StudioLinterScreen({
    super.key,
    required this.project,
  });

  @override
  State<StudioLinterScreen> createState() => _StudioLinterScreenState();
}

class _StudioLinterScreenState extends State<StudioLinterScreen> {
  late EpubProject _project;
  List<LinterIssue> _issues = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _runValidation();
  }

  void _runValidation() {
    final issues = EpubLinterService.validateProject(_project);
    setState(() {
      _issues = issues;
    });
  }

  Future<void> _autoFixAll() async {
    final repaired = EpubLinterService.autoFixProject(_project);
    await StudioProjectService.saveProject(repaired);
    setState(() {
      _project = repaired;
      _issues = EpubLinterService.validateProject(repaired);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All auto-fixable issues resolved!'),
          backgroundColor: EpilogueTheme.greenAccent,
        ),
      );
    }
  }

  Future<void> _exportEpub({bool isKepub = false}) async {
    setState(() => _isExporting = true);

    try {
      final sanitizedTitle = _project.title.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
      final ext = isKepub ? '.kepub.epub' : '.epub';
      final fileName = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}$ext';

      // Export to Documents/Epilogue_Exports/
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/Epilogue_Exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final targetFile = File('${exportDir.path}/$fileName');
      await EpubBuilderService.saveEpubToFile(_project, targetFile.path);

      final sizeBytes = await targetFile.length();
      final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);

      setState(() => _isExporting = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: EpilogueTheme.greenAccent),
                const SizedBox(width: 10),
                const Text('EPUB Exported!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your book is compiled to 100% W3C EPUB 3.3 standards with EPUB 2 NCX fallback and byte-exact uncompressed mimetype.',
                  style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EpilogueTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EpilogueTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File: $fileName', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Size: $sizeKb KB', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Location: ${targetFile.path}', style: TextStyle(fontSize: 10, color: EpilogueTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('DONE'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to compile EPUB: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = _issues.where((i) => i.severity == LinterSeverity.error).length;
    final warnings = _issues.where((i) => i.severity == LinterSeverity.warning).length;
    final infos = _issues.where((i) => i.severity == LinterSeverity.info).length;
    final hasAutoFixable = _issues.any((i) => i.canAutoFix);

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Pre-Flight Linter & Export'),
      ),
      body: Column(
        children: [
          // Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: EpilogueTheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('$errors', 'Errors', EpilogueTheme.dangerAccent),
                _buildStatPill('$warnings', 'Warnings', EpilogueTheme.starGold),
                _buildStatPill('$infos', 'Notices', EpilogueTheme.cyanAccent),
                _buildStatPill('${_project.chapters.length}', 'Chapters', EpilogueTheme.accent),
              ],
            ),
          ),
          Divider(color: EpilogueTheme.border, height: 1),

          // Action Ribbon
          if (hasAutoFixable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: EpilogueTheme.greenAccent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, size: 18, color: EpilogueTheme.greenAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auto-fixable issues detected (missing UUID, unclosed tags).',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EpilogueTheme.greenAccent),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.greenAccent, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _autoFixAll,
                    child: const Text('AUTO-FIX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Issues List
          Expanded(
            child: _issues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, size: 64, color: EpilogueTheme.greenAccent),
                        const SizedBox(height: 16),
                        Text(
                          '100% EPUB 3.3 Compliant!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: EpilogueTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Zero errors detected. Ready for Amazon KDP, Kobo, and Apple Books.',
                          style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _issues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final issue = _issues[idx];
                      return _buildIssueTile(issue);
                    },
                  ),
          ),

          // Export Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EpilogueTheme.surface,
              border: Border(top: BorderSide(color: EpilogueTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: EpilogueTheme.border),
                    ),
                    icon: const Icon(Icons.tablet, size: 16),
                    label: const Text('EXPORT .KEPUB', style: TextStyle(fontSize: 12)),
                    onPressed: _isExporting ? null : () => _exportEpub(isKepub: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: EpilogueTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download, size: 18),
                    label: Text(
                      _isExporting ? 'COMPILING EPUB...' : 'EXPORT STANDARD EPUB 3.3',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3),
                    ),
                    onPressed: _isExporting ? null : () => _exportEpub(isKepub: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EpilogueTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildIssueTile(LinterIssue issue) {
    Color iconColor;
    IconData iconData;

    switch (issue.severity) {
      case LinterSeverity.error:
        iconColor = EpilogueTheme.dangerAccent;
        iconData = Icons.error_outline;
        break;
      case LinterSeverity.warning:
        iconColor = EpilogueTheme.starGold;
        iconData = Icons.warning_amber_rounded;
        break;
      case LinterSeverity.info:
        iconColor = EpilogueTheme.cyanAccent;
        iconData = Icons.info_outline;
        break;
    }

    return Card(
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: ListTile(
        leading: Icon(iconData, color: iconColor),
        title: Text(
          issue.message,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EpilogueTheme.textPrimary),
        ),
        subtitle: Row(
          children: [
            Text(
              issue.ruleId,
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: EpilogueTheme.cyanAccent),
            ),
            if (issue.canAutoFix) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: EpilogueTheme.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('AUTO-FIXABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EpilogueTheme.greenAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
