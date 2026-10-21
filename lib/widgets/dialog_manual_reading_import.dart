import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class DialogManualReadingImport extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onSaved;

  const DialogManualReadingImport({
    super.key,
    required this.storageService,
    required this.onSaved,
  });

  @override
  State<DialogManualReadingImport> createState() => _DialogManualReadingImportState();
}

class _DialogManualReadingImportState extends State<DialogManualReadingImport> {
  final _hoursController = TextEditingController();
  final _wordsController = TextEditingController();
  final _volumesController = TextEditingController();
  final _pagesController = TextEditingController();
  final _streakController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _wordsController.dispose();
    _volumesController.dispose();
    _pagesController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  void _submit() async {
    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final words = int.tryParse(_wordsController.text.trim()) ?? 0;
    final volumes = int.tryParse(_volumesController.text.trim()) ?? 0;
    final pages = int.tryParse(_pagesController.text.trim()) ?? 0;
    final streakDays = int.tryParse(_streakController.text.trim()) ?? 0;

    final seconds = (hours * 3600).round();

    if (seconds <= 0 && words <= 0 && volumes <= 0 && pages <= 0 && streakDays <= 0) {
      Navigator.pop(context);
      return;
    }

    if (seconds > 0 || words > 0 || volumes > 0 || pages > 0) {
      await widget.storageService.addManualPastReading(
        additionalSeconds: seconds,
        additionalWords: words,
        additionalVolumes: volumes,
        additionalPages: pages,
      );
    }

    if (streakDays > 0) {
      await widget.storageService.importPastStreakDays(streakDays);
    }

    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reading history & streaks successfully synchronized.'),
          backgroundColor: EpilogueTheme.accent,
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
          Icon(Icons.history_edu, color: EpilogueTheme.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'Import Past Reads',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: EpilogueTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log reading hours, word count, and daily streak accumulated in past apps (Kindle, Moon+, Mihon, etc.) to merge into your telemetry.',
              style: TextStyle(fontSize: 13, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Reading Hours (e.g. 45.5)',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordsController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Words Read (e.g. 500000)',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Pages Read (e.g. 1250)',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _volumesController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Past Books/Volumes Completed',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _streakController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Past Consecutive Days Streak (e.g. 30)',
                labelStyle: TextStyle(color: EpilogueTheme.textSecondary),
                prefixIcon: const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EpilogueTheme.border)),
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
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: EpilogueTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('SYNC STATS', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
