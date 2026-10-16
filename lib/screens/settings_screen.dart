import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../config/reader_config.dart';
import '../services/data_sync_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';
import 'opds_browser_screen.dart';
import 'retrocognition_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ReaderConfig initialConfig;
  final StorageService storageService;
  final ValueChanged<ReaderConfig> onConfigChanged;

  const SettingsScreen({
    super.key,
    required this.initialConfig,
    required this.storageService,
    required this.onConfigChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ReaderConfig _config;
  late DataSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _syncService = DataSyncService(widget.storageService);
  }

  void _updateConfig(ReaderConfig next) {
    setState(() {
      _config = next;
    });
    widget.storageService.saveConfig(next);
    widget.onConfigChanged(next);
  }

  Future<void> _exportBackup() async {
    try {
      final path = await _syncService.exportBackupToFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved successfully to:\n$path'),
            backgroundColor: EpilogueTheme.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final content = await File(path).readAsString();
        final success = await _syncService.importBackupFromJson(content, smartMerge: true);

        if (mounted) {
          if (success) {
            final reloaded = widget.storageService.loadConfig();
            _updateConfig(reloaded);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup restored and merged successfully!'),
                backgroundColor: EpilogueTheme.accent,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid backup file format.'),
                backgroundColor: EpilogueTheme.dangerAccent,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import backup: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  void _showWebDavDialog() {
    final urlCtrl = TextEditingController(text: 'https://');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSyncing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: EpilogueTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: EpilogueTheme.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_sync, color: EpilogueTheme.cyanAccent),
              SizedBox(width: 10),
              Text('WebDAV Cloud Sync'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sync your library, progress, bookmarks, and telemetry to Nextcloud, ownCloud, or any WebDAV server with Smart Auto-Merge.',
                  style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'WebDAV Server URL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password / App Token'),
                ),
                if (isSyncing) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator(color: EpilogueTheme.accent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
            ),
            OutlinedButton(
              onPressed: isSyncing
                  ? null
                  : () async {
                      setDialogState(() => isSyncing = true);
                      final ok = await _syncService.pullFromWebDav(
                        serverUrl: urlCtrl.text.trim(),
                        username: userCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                      );
                      setDialogState(() => isSyncing = false);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Successfully synced from Cloud!' : 'Failed to pull from WebDAV server.'),
                            backgroundColor: ok ? EpilogueTheme.accent : EpilogueTheme.dangerAccent,
                          ),
                        );
                      }
                    },
              child: const Text('PULL (MERGE)'),
            ),
            FilledButton(
              onPressed: isSyncing
                  ? null
                  : () async {
                      setDialogState(() => isSyncing = true);
                      final ok = await _syncService.pushToWebDav(
                        serverUrl: urlCtrl.text.trim(),
                        username: userCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                      );
                      setDialogState(() => isSyncing = false);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Successfully pushed snapshot to Cloud!' : 'Failed to push to WebDAV server.'),
                            backgroundColor: ok ? EpilogueTheme.accent : EpilogueTheme.dangerAccent,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
              child: const Text('PUSH TO CLOUD'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Data Hub & Cloud Sync
          _buildCategoryHeader('DATA HUB & CLOUD SYNC', Icons.cloud_done),
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_edu, color: EpilogueTheme.starGold),
                    title: const Text('Retrocognition (과거 읽기 회상)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Migrate past chapters from other readers & compute historical telemetry', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RetrocognitionScreen(storageService: widget.storageService),
                        ),
                      );
                    },
                  ),
                  const Divider(color: EpilogueTheme.border, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wifi, color: EpilogueTheme.cyanAccent),
                    title: const Text('Online Catalogs & Downloader', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Connect to Calibre/Kavita OPDS servers or download direct web EPUBs', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OpdsBrowserScreen(storageService: widget.storageService),
                        ),
                      );
                    },
                  ),
                  const Divider(color: EpilogueTheme.border, height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportBackup,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('EXPORT JSON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importBackup,
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('IMPORT JSON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showWebDavDialog,
                      icon: const Icon(Icons.cloud_sync, size: 18),
                      label: const Text('WEBDAV CLOUD SYNC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Interface & Display
          _buildCategoryHeader('INTERFACE & DISPLAY', Icons.display_settings),
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Global UI Scale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: EpilogueTheme.textPrimary)),
                          SizedBox(height: 2),
                          Text('Scale entire app buttons & typography', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(_config.uiScale * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _config.uiScale,
                    min: 0.85,
                    max: 1.35,
                    divisions: 10,
                    activeColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(uiScale: val)),
                  ),
                  const Divider(color: EpilogueTheme.border, height: 20),

                  const Text('Reading Theme Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _themePresetTile(ReaderThemePreset.paperLight, 'Pure Paper', const Color(0xFFFFFFFF), const Color(0xFF111827)),
                      const SizedBox(width: 8),
                      _themePresetTile(ReaderThemePreset.sepiaWarm, 'Warm Book', const Color(0xFFFBF0D9), const Color(0xFF2C2416)),
                      const SizedBox(width: 8),
                      _themePresetTile(ReaderThemePreset.slateGray, 'Slate Gray', const Color(0xFFE2E8F0), const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      _themePresetTile(ReaderThemePreset.oledDark, 'OLED Ink', Colors.black, const Color(0xFFE5E7EB)),
                    ],
                  ),
                  const Divider(color: EpilogueTheme.border, height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep Screen Awake', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Prevents display dimming while reading', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.keepScreenAwake,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(keepScreenAwake: val)),
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Reading Header & Footer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Displays subtle book title and chapter progress in canvas', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.showReadingHeaderFooter,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(showReadingHeaderFooter: val)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Navigation & Controls
          _buildCategoryHeader('NAVIGATION & CONTROLS', Icons.navigation),
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Volume Keys Page Turn', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Use hardware volume up/down buttons to turn pages', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.volumeKeysPaging,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(volumeKeysPaging: val)),
                  ),
                  const Divider(color: EpilogueTheme.border, height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Haptic Tap Feedback', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Light vibration feedback when turning pages', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.hapticFeedback,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(hapticFeedback: val)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Star Stream & ORV Lore
          _buildCategoryHeader('STAR STREAM STYLING', Icons.auto_awesome),
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Star Stream Constellation CSS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Renders constellation notifications [...] with distinctive glowing cyan border and monospace font', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.customCssEnabled,
                    activeThumbColor: EpilogueTheme.cyanAccent,
                    onChanged: (val) => _updateConfig(_config.copyWith(customCssEnabled: val)),
                  ),
                  const Divider(color: EpilogueTheme.border, height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Original Book Formatting (EPUB CSS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('Renders original chapter headings, centered text, dividers, and styling classes embedded in the EPUB', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.useOriginalBookStyles,
                    activeThumbColor: EpilogueTheme.cyanAccent,
                    onChanged: (val) => _updateConfig(_config.copyWith(useOriginalBookStyles: val)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield, color: EpilogueTheme.cyanAccent, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '[Exclusive Skill: "The 4th Wall" can be activated from the in-reader HUD.]',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: EpilogueTheme.border, height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt, color: EpilogueTheme.dangerAccent),
                    title: const Text('Reset Progression to Blank Slate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.dangerAccent)),
                    subtitle: const Text('Wipes coins, locks all modifiers, attributes, & fables. Preserves library books.', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    onTap: _showResetProgressionDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetProgressionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: EpilogueTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: EpilogueTheme.dangerAccent),
            SizedBox(width: 10),
            Text('Reset to Blank Slate?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset your Star Stream progression? All coins, unlocked modifiers, attributes, and fables will be reset to a true blank slate. Your book library and reader settings are kept safe.',
          style: TextStyle(fontSize: 13, color: EpilogueTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.dangerAccent),
            onPressed: () async {
              await widget.storageService.resetOrvStateToBlankSlate();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Star Stream progression reset to blank slate.'),
                    backgroundColor: EpilogueTheme.dangerAccent,
                  ),
                );
              }
            },
            child: const Text('RESET TO BLANK SLATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: EpilogueTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: EpilogueTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _themePresetTile(ReaderThemePreset preset, String label, Color bg, Color text) {
    final isSelected = _config.themePreset == preset;
    return Expanded(
      child: InkWell(
        onTap: () => _updateConfig(_config.copyWith(themePreset: preset)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? EpilogueTheme.accent : EpilogueTheme.border,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Aa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
