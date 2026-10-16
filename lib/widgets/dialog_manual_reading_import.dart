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

  @override
  void dispose() {
    _hoursController.dispose();
    _wordsController.dispose();
    _volumesController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  void _submit() async {
    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final words = int.tryParse(_wordsController.text.trim()) ?? 0;
    final volumes = int.tryParse(_volumesController.text.trim()) ?? 0;
    final pages = int.tryParse(_pagesController.text.trim()) ?? 0;

    final seconds = (hours * 3600).round();

    if (seconds <= 0 && words <= 0 && volumes <= 0 && pages <= 0) {
      Navigator.pop(context);
      return;
    }

    await widget.storageService.addManualPastReading(
      additionalSeconds: seconds,
      additionalWords: words,
      additionalVolumes: volumes,
      additionalPages: pages,
    );

    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading history successfully synchronized.'),
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
        side: const BorderSide(color: EpilogueTheme.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.history_edu, color: EpilogueTheme.accent, size: 22),
          SizedBox(width: 8),
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
            const Text(
              'Log reading hours and word count accumulated in past apps (Kindle, Moon+, Mihon, etc.) to merge into your telemetry.',
              style: TextStyle(fontSize: 13, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Reading Hours (e.g. 45.5)',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Words Read (e.g. 500000)',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Past Pages Read (e.g. 1250)',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EpilogueTheme.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _volumesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: EpilogueTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Past Books/Volumes Completed',
                labelStyle: const TextStyle(color: EpilogueTheme.textSecondary),
                filled: true,
                fillColor: EpilogueTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EpilogueTheme.border)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
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
