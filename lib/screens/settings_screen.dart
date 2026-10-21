import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../config/reader_config.dart';
import '../services/data_sync_service.dart';
import '../services/storage_service.dart';
import '../services/update_checker_service.dart';
import '../services/url_launcher_service.dart';
import '../theme/epilogue_theme.dart';
import 'changelog_screen.dart';
import 'feature_manual_screen.dart';
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
    EpilogueTheme.applyConfig(next);
    widget.storageService.saveConfig(next);
    widget.onConfigChanged(next);
  }

  // Backup & Restore
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
              SnackBar(
                content: const Text('Backup restored and merged successfully!'),
                backgroundColor: EpilogueTheme.accent,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Invalid backup file format.'),
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
            side: BorderSide(color: EpilogueTheme.border),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_sync, color: EpilogueTheme.cyanAccent),
              const SizedBox(width: 10),
              const Text('WebDAV Cloud Sync'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                  Center(child: CircularProgressIndicator(color: EpilogueTheme.accent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
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

  // Update Checker with Actionable Download & GitHub Releases
  Future<void> _handleCheckForUpdates() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        content: Row(
          children: [
            CircularProgressIndicator(color: EpilogueTheme.cyanAccent),
            const SizedBox(width: 16),
            const Expanded(child: Text('Connecting to release server...', style: TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );

    final res = await UpdateCheckerService.checkForUpdates();
    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

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
            Icon(
              res.status == UpdateStatus.updateAvailable
                  ? Icons.system_update
                  : (res.status == UpdateStatus.upToDate ? Icons.check_circle : Icons.error_outline),
              color: res.status == UpdateStatus.updateAvailable
                  ? EpilogueTheme.cyanAccent
                  : (res.status == UpdateStatus.upToDate ? EpilogueTheme.greenAccent : EpilogueTheme.dangerAccent),
            ),
            const SizedBox(width: 10),
            Text(
              res.status == UpdateStatus.updateAvailable
                  ? 'Update Available!'
                  : (res.status == UpdateStatus.upToDate ? 'Up to Date' : 'Check Status'),
              style: TextStyle(
                color: EpilogueTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Installed: ${res.currentVersion}',
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            if (res.status == UpdateStatus.updateAvailable) ...[
              Text(
                'Latest Available: v${res.latestVersion}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: EpilogueTheme.cyanAccent,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    res.releaseNotes,
                    style: TextStyle(fontSize: 12, color: EpilogueTheme.textPrimary, height: 1.4),
                  ),
                ),
              ),
            ] else if (res.status == UpdateStatus.upToDate) ...[
              Text(
                res.releaseNotes,
                style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
              ),
            ] else ...[
              Text(
                res.errorMessage ?? 'Unable to connect to release server.',
                style: TextStyle(fontSize: 12, color: EpilogueTheme.dangerAccent),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
          if (res.status == UpdateStatus.updateAvailable) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
              icon: const Icon(Icons.download, size: 16),
              label: Text('DOWNLOAD v${res.latestVersion}'),
              onPressed: () {
                Navigator.pop(ctx);
                if (res.downloadUrl != null) {
                  UrlLauncherService.openUrl(res.downloadUrl!, context: context);
                }
              },
            ),
          ] else ...[
            TextButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('RELEASES PAGE'),
              onPressed: () {
                Navigator.pop(ctx);
                UrlLauncherService.openReleases(context);
              },
            ),
          ],
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
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: EpilogueTheme.dangerAccent),
            const SizedBox(width: 10),
            const Text('Reset to Blank Slate?'),
          ],
        ),
        content: Text(
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
                  SnackBar(
                    content: const Text('Star Stream progression reset to blank slate.'),
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

  void _toggleFourthWall(bool enable) {
    final next = _config.copyWith(fourthWallActive: enable);
    _updateConfig(next);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? '[The exclusive skill, \'The 4th Wall\' has been activated.]'
                : '[The exclusive skill, \'The 4th Wall\' has been deactivated.]',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
              color: Color(0xFFE6F1FF),
            ),
          ),
          backgroundColor: enable ? const Color(0xFF0A192F) : EpilogueTheme.accent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: enable ? const Color(0xFF64FFDA) : EpilogueTheme.border,
              width: 1.5,
            ),
          ),
        ),
      );
    }
  }

  void _showCustomHexDialog() {
    final hexCtrl = TextEditingController(text: _config.fourthWallHexColor);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Custom 4th Wall Hex Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a 6-digit hex color code (e.g., #0B192C, #0F172A, #10002B):',
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hexCtrl,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Hex Color Code',
                hintText: '#0A192F',
                prefixIcon: Icon(Icons.palette),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF64FFDA)),
            onPressed: () {
              var hex = hexCtrl.text.trim();
              if (!hex.startsWith('#')) hex = '#$hex';
              if (RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$').hasMatch(hex)) {
                _updateConfig(_config.copyWith(fourthWallHexColor: hex));
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Invalid hex color format. Use #RRGGBB.'),
                    backgroundColor: EpilogueTheme.dangerAccent,
                  ),
                );
              }
            },
            child: const Text('APPLY HEX', style: TextStyle(color: Color(0xFF0A192F))),
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

  Widget _fourthWallColorChip(String label, String hex) {
    final isSelected = _config.fourthWallHexColor.toUpperCase() == hex.toUpperCase();
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isSelected ? const Color(0xFF0A192F) : EpilogueTheme.textPrimary,
      ),
      selectedColor: const Color(0xFF64FFDA),
      backgroundColor: EpilogueTheme.surfaceElevated,
      side: BorderSide(
        color: isSelected ? const Color(0xFF64FFDA) : EpilogueTheme.border,
      ),
      onSelected: (_) => _updateConfig(_config.copyWith(fourthWallHexColor: hex)),
    );
  }

  // --- ANDROID SETTINGS SUB-PAGES ---

  Widget _buildDisplaySettingsPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('Display & Appearance')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Global UI Scale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: EpilogueTheme.textPrimary)),
                          const SizedBox(height: 2),
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent, fontSize: 12),
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
                  Divider(color: EpilogueTheme.border, height: 20),

                  Text('Reading Theme Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
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
                  Divider(color: EpilogueTheme.border, height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Keep Screen Awake', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Prevents display dimming while reading', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.keepScreenAwake,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(keepScreenAwake: val)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Show Reading Header & Footer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Displays subtle book title and chapter progress in canvas', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.showReadingHeaderFooter,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(showReadingHeaderFooter: val)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // The 4th Wall Consciousness Shield
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _config.fourthWallActive
                  ? const Color(0xFF0A192F).withValues(alpha: 0.9)
                  : EpilogueTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _config.fourthWallActive
                    ? const Color(0xFF64FFDA)
                    : EpilogueTheme.border,
                width: _config.fourthWallActive ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(
                        _config.fourthWallActive ? Icons.shield : Icons.shield_outlined,
                        color: _config.fourthWallActive ? const Color(0xFF64FFDA) : EpilogueTheme.cyanAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'The 4th Wall Consciousness Shield',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF64FFDA),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Shifts entire UI into Midnight Blue or custom hex, shielding reading consciousness.',
                    style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
                  ),
                  value: _config.fourthWallActive,
                  activeThumbColor: const Color(0xFF64FFDA),
                  onChanged: _toggleFourthWall,
                ),
                if (_config.fourthWallActive) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Shield Hex Color Palette:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _fourthWallColorChip('Midnight Blue', '#0A192F'),
                      _fourthWallColorChip('Abyssal Navy', '#0D1B2A'),
                      _fourthWallColorChip('Cyber Teal', '#022B3A'),
                      _fourthWallColorChip('Void Indigo', '#10002B'),
                      ActionChip(
                        avatar: const Icon(Icons.colorize, size: 14, color: Color(0xFF64FFDA)),
                        label: Text(
                          'Custom: ${_config.fourthWallHexColor}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                        onPressed: _showCustomHexDialog,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingControlsPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('Reading Engine & Controls')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Volume Keys Page Turn', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Use hardware volume up/down buttons to turn pages', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.volumeKeysPaging,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(volumeKeysPaging: val)),
                  ),
                  Divider(color: EpilogueTheme.border, height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Haptic Tap Feedback', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Light vibration feedback when turning pages', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.hapticFeedback,
                    activeThumbColor: EpilogueTheme.accent,
                    onChanged: (val) => _updateConfig(_config.copyWith(hapticFeedback: val)),
                  ),
                  Divider(color: EpilogueTheme.border, height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Star Stream Constellation CSS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Renders constellation notifications [...] with glowing cyan border and monospace font', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.customCssEnabled,
                    activeThumbColor: EpilogueTheme.cyanAccent,
                    onChanged: (val) => _updateConfig(_config.copyWith(customCssEnabled: val)),
                  ),
                  Divider(color: EpilogueTheme.border, height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Original Book Formatting (EPUB CSS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Renders original chapter headings, centered text, dividers, and styling classes embedded in the EPUB', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    value: _config.useOriginalBookStyles,
                    activeThumbColor: EpilogueTheme.cyanAccent,
                    onChanged: (val) => _updateConfig(_config.copyWith(useOriginalBookStyles: val)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataHubPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('Data Hub & Cloud Sync')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_edu, color: EpilogueTheme.starGold),
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
                  Divider(color: EpilogueTheme.border, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.wifi, color: EpilogueTheme.cyanAccent),
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
                  Divider(color: EpilogueTheme.border, height: 16),
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
        ],
      ),
    );
  }

  Widget _buildLibraryProgressionPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('Library & Progression')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.restart_alt, color: EpilogueTheme.dangerAccent),
                title: Text('Reset Progression to Blank Slate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.dangerAccent)),
                subtitle: Text('Wipes coins, locks all modifiers, attributes, & fables. Preserves library books and reader config.', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                onTap: _showResetProgressionDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitySupportPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('Community & Support')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.discord, color: Color(0xFF5865F2), size: 20),
                    ),
                    title: const Text('Join Discord Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Chat with readers, share EPUB studio creations & get support', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => UrlLauncherService.openDiscord(context),
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.dangerAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.bug_report_outlined, color: EpilogueTheme.dangerAccent, size: 20),
                    ),
                    title: const Text('Report a Bug / Issues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Open an issue on GitHub to request features or report bugs', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => UrlLauncherService.openReportBug(context),
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_outline, color: EpilogueTheme.cyanAccent, size: 20),
                    ),
                    title: const Text('Developer GitHub Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Follow @EtherealInsanity on GitHub', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => UrlLauncherService.openDeveloperProfile(context),
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.code, color: EpilogueTheme.textPrimary, size: 20),
                    ),
                    title: const Text('GitHub Source Repository', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('View open-source code, releases, and star the repo', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => UrlLauncherService.openGithubRepo(context),
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.starGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.menu_book, color: EpilogueTheme.starGold, size: 20),
                    ),
                    title: const Text('Epilogue Grimoire & Feature Manual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('In-app documentation explaining all systems & reader mechanics', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeatureManualScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutUpdatesPage() {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(title: const Text('About & System Updates')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.system_update_alt, color: EpilogueTheme.cyanAccent, size: 20),
                    ),
                    title: Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('Epilogue v${UpdateCheckerService.currentVersion}', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    trailing: Icon(Icons.chevron_right, size: 20, color: EpilogueTheme.textMuted),
                    onTap: _handleCheckForUpdates,
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.greenAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.history_toggle_off, color: EpilogueTheme.greenAccent, size: 20),
                    ),
                    title: Text('Update Changelog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: Text('What\'s new, improvements, and bug fixes', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    trailing: Icon(Icons.chevron_right, size: 20, color: EpilogueTheme.textMuted),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangelogScreen()),
                    ),
                  ),
                  Divider(color: EpilogueTheme.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.verified_outlined, color: EpilogueTheme.accent, size: 20),
                    ),
                    title: Text('License & Integrity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                    subtitle: const Text('100% Free & Open Source • Zero Ads • Zero Tracking • MIT', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Epilogue',
                        applicationVersion: 'v${UpdateCheckerService.currentVersion}',
                        applicationLegalese: 'MIT License • Copyright (c) 2026 EtherealInsanity',
                        children: [
                          const SizedBox(height: 12),
                          const Text('Immersive EPUB & Web Novel Reader with Studio Authoring & Star Stream Progression.'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MAIN SETTINGS HUB (ANDROiD SETTINGS STYLE) ---

  Widget _buildCategoryTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget Function() pageBuilder,
  }) {
    return Card(
      color: EpilogueTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: EpilogueTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary, height: 1.3),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: EpilogueTheme.textMuted),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pageBuilder()),
          );
        },
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
          _buildCategoryTile(
            icon: Icons.palette_outlined,
            iconColor: EpilogueTheme.cyanAccent,
            title: 'Display & Appearance',
            subtitle: 'Global UI scale, theme presets, The 4th Wall shield',
            pageBuilder: _buildDisplaySettingsPage,
          ),
          _buildCategoryTile(
            icon: Icons.menu_book_outlined,
            iconColor: EpilogueTheme.greenAccent,
            title: 'Reading Engine & Controls',
            subtitle: 'Volume keys paging, haptics, constellation CSS, original book styles',
            pageBuilder: _buildReadingControlsPage,
          ),
          _buildCategoryTile(
            icon: Icons.cloud_sync_outlined,
            iconColor: EpilogueTheme.starGold,
            title: 'Data Hub & Cloud Sync',
            subtitle: 'Retrocognition, online OPDS catalogs, JSON backup, WebDAV sync',
            pageBuilder: _buildDataHubPage,
          ),
          _buildCategoryTile(
            icon: Icons.shield_outlined,
            iconColor: EpilogueTheme.dangerAccent,
            title: 'Library & Progression',
            subtitle: 'Reset Star Stream progression to blank slate',
            pageBuilder: _buildLibraryProgressionPage,
          ),
          _buildCategoryTile(
            icon: Icons.forum_outlined,
            iconColor: const Color(0xFF5865F2),
            title: 'Community & Support',
            subtitle: 'Join Discord, report bugs on GitHub, developer profile & grimoire',
            pageBuilder: _buildCommunitySupportPage,
          ),
          _buildCategoryTile(
            icon: Icons.system_update_alt_outlined,
            iconColor: EpilogueTheme.accent,
            title: 'About & System Updates',
            subtitle: 'Check for updates, changelog, version info & open source license',
            pageBuilder: _buildAboutUpdatesPage,
          ),
        ],
      ),
    );
  }
}
