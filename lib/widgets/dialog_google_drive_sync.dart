import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../services/data_sync_service.dart';
import '../services/google_drive_sync_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';
import 'dialog_backup_import_selection.dart';

class DialogGoogleDriveSync extends StatefulWidget {
  final StorageService storageService;
  final DataSyncService dataSyncService;
  final GoogleDriveSyncService? syncService;
  final VoidCallback? onSyncCompleted;

  const DialogGoogleDriveSync({
    super.key,
    required this.storageService,
    required this.dataSyncService,
    this.syncService,
    this.onSyncCompleted,
  });

  @override
  State<DialogGoogleDriveSync> createState() => _DialogGoogleDriveSyncState();
}

class _DialogGoogleDriveSyncState extends State<DialogGoogleDriveSync> {
  late final GoogleDriveSyncService _syncService;

  bool _isLoading = false;
  String _statusText = '';
  double _progressFraction = 0.0;
  CloudSnapshotInfo? _cloudInfo;
  bool _checkingCloudInfo = false;

  @override
  void initState() {
    super.initState();
    _syncService = widget.syncService ??
        GoogleDriveSyncService(
          storageService: widget.storageService,
          dataSyncService: widget.dataSyncService,
        );
    _checkInitialAccount();
  }

  Future<void> _checkInitialAccount() async {
    setState(() => _checkingCloudInfo = true);
    try {
      await _syncService.signInSilently();
      if (_syncService.isSignedIn) {
        _cloudInfo = await _syncService.getCloudSnapshotInfo();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _checkingCloudInfo = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Signing in to Google...';
      _progressFraction = 0.1;
    });

    final account = await _syncService.signIn();
    if (account != null) {
      _cloudInfo = await _syncService.getCloudSnapshotInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected as ${account.email}'),
            backgroundColor: EpilogueTheme.accent,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google Sign-In was cancelled or failed. Check credentials setup.'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusText = '';
        _progressFraction = 0.0;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _syncService.signOut();
    setState(() {
      _cloudInfo = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Signed out of Google Drive.'),
          backgroundColor: EpilogueTheme.surface,
        ),
      );
    }
  }

  Future<void> _handlePush() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Starting cloud push...';
      _progressFraction = 0.0;
    });

    final result = await _syncService.pushBackupAndLibrary(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _statusText = status;
            _progressFraction = progress;
          });
        }
      },
    );

    _cloudInfo = await _syncService.getCloudSnapshotInfo();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusText = '';
        _progressFraction = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? EpilogueTheme.accent : EpilogueTheme.dangerAccent,
          duration: const Duration(seconds: 4),
        ),
      );

      if (result.success) {
        widget.onSyncCompleted?.call();
      }
    }
  }

  Future<void> _handlePull() async {
    // 1. Fetch cloud info and inspect backup file first
    setState(() {
      _isLoading = true;
      _statusText = 'Checking cloud snapshot...';
      _progressFraction = 0.1;
    });

    final api = await _syncService.getDriveApi();
    if (api == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please sign in to Google first.'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return;
    }

    final rootId = await _syncService.getOrCreateFolder(api, GoogleDriveSyncService.rootFolderName);
    final backupFile = rootId != null
        ? await _syncService.findFile(api, GoogleDriveSyncService.backupFileName, parentId: rootId)
        : null;

    if (backupFile?.id == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No Epilogue backup found in Google Drive.'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return;
    }

    // 2. Download snapshot to preview summary
    setState(() {
      _statusText = 'Loading backup summary...';
      _progressFraction = 0.25;
    });

    final dl = await api.files.get(
      backupFile!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    String? backupJson;
    if (dl is drive.Media) {
      final bytes = <int>[];
      await for (final chunk in dl.stream) {
        bytes.addAll(chunk);
      }
      backupJson = utf8.decode(bytes);
    }

    setState(() => _isLoading = false);

    if (backupJson == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to read backup from Google Drive.'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return;
    }

    final summary = BackupSummary.fromJson(backupJson);
    if (summary == null || summary.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cloud backup contains invalid or empty data.'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show selective import dialog
    final options = await showDialog<BackupImportOptions>(
      context: context,
      builder: (_) => DialogBackupImportSelection(summary: summary),
    );

    if (options == null || !options.hasAnySelected) return;

    // Execute full pull and restore missing EPUBs
    setState(() {
      _isLoading = true;
      _statusText = 'Restoring library & reading state...';
      _progressFraction = 0.3;
    });

    final result = await _syncService.pullBackupAndLibrary(
      options: options,
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _statusText = status;
            _progressFraction = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusText = '';
        _progressFraction = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? EpilogueTheme.accent : EpilogueTheme.dangerAccent,
          duration: const Duration(seconds: 4),
        ),
      );

      if (result.success) {
        widget.onSyncCompleted?.call();
      }
    }
  }

  void _showCredentialsHelper() {
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
            Icon(Icons.vpn_key_outlined, color: EpilogueTheme.starGold),
            const SizedBox(width: 10),
            const Text('Google Cloud Credentials'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To use Google Sign-In, add an Android OAuth 2.0 Client ID in your Google Cloud Console project with these values:',
                style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              _buildCredentialTile(
                ctx,
                label: 'Package Name',
                value: 'com.epilogue.read',
              ),
              const SizedBox(height: 10),
              _buildCredentialTile(
                ctx,
                label: 'Permanent Release SHA-1',
                value: 'DD:F0:E4:AB:F0:37:7A:D8:DD:61:9B:D9:B2:D4:38:B3:11:6E:AB:5E',
              ),
              const SizedBox(height: 10),
              _buildCredentialTile(
                ctx,
                label: 'Debug Keystore SHA-1 (Dev)',
                value: '0E:CD:AF:AA:C9:AC:F4:80:EA:33:71:58:4B:9A:27:11:BA:6B:45:EE',
              ),
              const SizedBox(height: 14),
              Text(
                'Scopes: Enable "Google Drive API" and add the scope:\nhttps://www.googleapis.com/auth/drive.file',
                style: TextStyle(fontSize: 11, color: EpilogueTheme.cyanAccent),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTile(BuildContext ctx, {required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EpilogueTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EpilogueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Copied $label to clipboard!'), duration: const Duration(seconds: 2)),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 12, color: EpilogueTheme.starGold),
                    const SizedBox(width: 4),
                    Text('Copy', style: TextStyle(fontSize: 10, color: EpilogueTheme.starGold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _syncService.currentUser;
    final isConnected = _syncService.isSignedIn;

    return AlertDialog(
      backgroundColor: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      title: Row(
        children: [
          Icon(Icons.add_to_drive, color: EpilogueTheme.cyanAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Google Drive Cloud Sync',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: EpilogueTheme.starGold, size: 20),
            tooltip: 'Credentials & Setup Info',
            onPressed: _showCredentialsHelper,
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync your reading telemetry, progress, highlights, and entire EPUB library to Google Drive with automatic file-deduplication.',
                style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
              ),
              const SizedBox(height: 16),

              // Account Status Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EpilogueTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EpilogueTheme.border),
                ),
                child: isConnected
                    ? Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: EpilogueTheme.accent,
                            backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                            child: user?.photoUrl == null
                                ? Text(
                                    user?.displayName?.isNotEmpty == true
                                        ? user!.displayName![0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Connected Account',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user?.email ?? 'Google Drive Cloud Active',
                                  style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _handleSignOut,
                            child: Text(
                              'SIGN OUT',
                              style: TextStyle(fontSize: 11, color: EpilogueTheme.dangerAccent),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Not Connected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Sign in to sync your library', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _handleSignIn,
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('SIGN IN'),
                            style: FilledButton.styleFrom(
                              backgroundColor: EpilogueTheme.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // Cloud Snapshot Stats
              if (isConnected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: EpilogueTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EpilogueTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_outlined, size: 18, color: EpilogueTheme.cyanAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _checkingCloudInfo
                            ? Text('Checking cloud status...', style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary))
                            : Text(
                                _cloudInfo?.lastModified != null
                                    ? 'Last backup: ${_formatDate(_cloudInfo!.lastModified!)} • ${_cloudInfo!.cloudBookCount} novels in cloud'
                                    : 'No existing cloud backup snapshot found.',
                                style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Active Sync Progress Indicator
              if (_isLoading) ...[
                LinearProgressIndicator(
                  value: _progressFraction > 0 ? _progressFraction : null,
                  backgroundColor: EpilogueTheme.background,
                  color: EpilogueTheme.cyanAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: TextStyle(fontSize: 11, color: EpilogueTheme.starGold, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('CLOSE', style: TextStyle(color: EpilogueTheme.textSecondary)),
        ),
        if (isConnected) ...[
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handlePull,
            icon: const Icon(Icons.cloud_download, size: 16),
            label: const Text('PULL (RESTORE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _handlePush,
            icon: const Icon(Icons.cloud_upload, size: 16),
            label: const Text('PUSH (BACKUP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
