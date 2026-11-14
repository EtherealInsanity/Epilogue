import 'package:flutter/material.dart';
import '../services/data_sync_service.dart';
import '../theme/epilogue_theme.dart';

class DialogBackupImportSelection extends StatefulWidget {
  final BackupSummary summary;

  const DialogBackupImportSelection({
    super.key,
    required this.summary,
  });

  @override
  State<DialogBackupImportSelection> createState() => _DialogBackupImportSelectionState();
}

class _DialogBackupImportSelectionState extends State<DialogBackupImportSelection> {
  late bool _importBookmarks;
  late bool _importHighlights;
  late bool _importTelemetry;
  late bool _importBooks;
  late bool _importShelves;
  late bool _importOrvState;
  late bool _importSettings;

  @override
  void initState() {
    super.initState();
    final s = widget.summary;
    _importBookmarks = s.bookmarkCount > 0;
    _importHighlights = s.highlightCount > 0;
    _importTelemetry = s.sessionCount > 0 || s.dailyRecordCount > 0;
    _importBooks = s.bookCount > 0;
    _importShelves = s.shelfCount > 0;
    _importOrvState = s.hasOrvState;
    _importSettings = s.hasSettings;
  }

  bool get _hasAnySelected =>
      _importBookmarks ||
      _importHighlights ||
      _importTelemetry ||
      _importBooks ||
      _importShelves ||
      _importOrvState ||
      _importSettings;

  void _selectAll(bool select) {
    final s = widget.summary;
    setState(() {
      _importBookmarks = select && s.bookmarkCount > 0;
      _importHighlights = select && s.highlightCount > 0;
      _importTelemetry = select && (s.sessionCount > 0 || s.dailyRecordCount > 0);
      _importBooks = select && s.bookCount > 0;
      _importShelves = select && s.shelfCount > 0;
      _importOrvState = select && s.hasOrvState;
      _importSettings = select && s.hasSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return AlertDialog(
      backgroundColor: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      title: Row(
        children: [
          Icon(Icons.settings_backup_restore, color: EpilogueTheme.cyanAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Select What to Import',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose which categories to import and merge into your local library:',
                style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _selectAll(true),
                    child: Text('SELECT ALL', style: TextStyle(fontSize: 11, color: EpilogueTheme.cyanAccent)),
                  ),
                  TextButton(
                    onPressed: () => _selectAll(false),
                    child: Text('CLEAR ALL', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                  ),
                ],
              ),
              const Divider(height: 8),
              _buildOptionTile(
                title: 'Bookmarks',
                subtitle: '${s.bookmarkCount} bookmark(s) found',
                icon: Icons.bookmark_added_outlined,
                value: _importBookmarks,
                available: s.bookmarkCount > 0,
                onChanged: (v) => setState(() => _importBookmarks = v),
              ),
              _buildOptionTile(
                title: 'Highlights & Notes',
                subtitle: '${s.highlightCount} highlight(s) found',
                icon: Icons.format_quote_outlined,
                value: _importHighlights,
                available: s.highlightCount > 0,
                onChanged: (v) => setState(() => _importHighlights = v),
              ),
              _buildOptionTile(
                title: 'Reading Telemetry',
                subtitle: '${s.sessionCount} session(s), ${s.dailyRecordCount} daily record(s)',
                icon: Icons.insights_outlined,
                value: _importTelemetry,
                available: s.sessionCount > 0 || s.dailyRecordCount > 0,
                onChanged: (v) => setState(() => _importTelemetry = v),
              ),
              _buildOptionTile(
                title: 'Books & Reading Progress',
                subtitle: '${s.bookCount} book(s) found',
                icon: Icons.auto_stories_outlined,
                value: _importBooks,
                available: s.bookCount > 0,
                onChanged: (v) => setState(() => _importBooks = v),
              ),
              _buildOptionTile(
                title: 'Bookshelves',
                subtitle: '${s.shelfCount} shelf/shelves found',
                icon: Icons.shelves,
                value: _importShelves,
                available: s.shelfCount > 0,
                onChanged: (v) => setState(() => _importShelves = v),
              ),
              _buildOptionTile(
                title: 'Star Stream Progression',
                subtitle: 'Coins, fables, modifiers, and scenarios',
                icon: Icons.military_tech_outlined,
                value: _importOrvState,
                available: s.hasOrvState,
                onChanged: (v) => setState(() => _importOrvState = v),
              ),
              _buildOptionTile(
                title: 'Settings & Preferences',
                subtitle: 'Theme, fonts, layout, and reader options',
                icon: Icons.tune_outlined,
                value: _importSettings,
                available: s.hasSettings,
                onChanged: (v) => setState(() => _importSettings = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: _hasAnySelected
              ? () {
                  Navigator.pop(
                    context,
                    BackupImportOptions(
                      importBooks: _importBooks,
                      importBookmarks: _importBookmarks,
                      importHighlights: _importHighlights,
                      importTelemetry: _importTelemetry,
                      importShelves: _importShelves,
                      importOrvState: _importOrvState,
                      importSettings: _importSettings,
                    ),
                  );
                }
              : null,
          style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
          child: const Text('IMPORT SELECTED'),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool available,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: available ? 1.0 : 0.4,
      child: CheckboxListTile(
        value: available ? value : false,
        onChanged: available ? (v) => onChanged(v ?? false) : null,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: available ? EpilogueTheme.textPrimary : EpilogueTheme.textSecondary,
          ),
        ),
        subtitle: Text(
          available ? subtitle : 'Not found in this backup',
          style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
        ),
        secondary: Icon(
          icon,
          color: available && value ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
          size: 20,
        ),
        dense: true,
        activeColor: EpilogueTheme.accent,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
