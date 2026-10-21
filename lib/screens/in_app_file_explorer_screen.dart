import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book_info.dart';
import '../services/file_explorer_service.dart';
import '../services/storage_permission_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class InAppFileExplorerScreen extends StatefulWidget {
  final StorageService storageService;
  final Function(BookInfo)? onBookSelected;

  const InAppFileExplorerScreen({
    super.key,
    required this.storageService,
    this.onBookSelected,
  });

  @override
  State<InAppFileExplorerScreen> createState() => _InAppFileExplorerScreenState();
}

class _InAppFileExplorerScreenState extends State<InAppFileExplorerScreen> {
  late FileExplorerService _explorerService;
  String _currentPath = FileExplorerService.rootStoragePath;
  List<FileSystemEntity> _entries = [];
  bool _isLoading = true;
  bool _hasStoragePermission = true;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _explorerService = FileExplorerService(widget.storageService);
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    final granted = await StoragePermissionService.hasStoragePermission();
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }
    // Prefer starting in Documents or Manga if available
    final mangaDir = Directory('${FileExplorerService.rootStoragePath}/Documents/Manga');
    if (await mangaDir.exists()) {
      _navigateTo(mangaDir.path);
    } else {
      final docDir = Directory('${FileExplorerService.rootStoragePath}/Documents');
      if (await docDir.exists()) {
        _navigateTo(docDir.path);
      } else {
        _navigateTo(FileExplorerService.rootStoragePath);
      }
    }
  }

  Future<void> _requestPermission() async {
    await StoragePermissionService.requestStoragePermission();
    // Re-check permission after user returns from settings
    Future.delayed(const Duration(seconds: 1), () async {
      final granted = await StoragePermissionService.hasStoragePermission();
      if (mounted) {
        setState(() => _hasStoragePermission = granted);
        if (granted) {
          _navigateTo(_currentPath);
        }
      }
    });
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _isLoading = true;
      _currentPath = path;
      _statusMsg = '';
    });

    final items = await _explorerService.listDirectory(path);
    if (mounted) {
      setState(() {
        _entries = items;
        _isLoading = false;
      });
    }
  }

  void _goUp() {
    if (_currentPath == FileExplorerService.rootStoragePath || _currentPath == '/') {
      return;
    }
    final parent = Directory(_currentPath).parent.path;
    _navigateTo(parent);
  }

  Future<void> _importAllInCurrent() async {
    setState(() {
      _isLoading = true;
      _statusMsg = 'Scanning directory for EPUBs...';
    });

    final count = await _explorerService.importFolderEpubs(_currentPath);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMsg = 'Imported $count EPUB novel(s) to Library!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $count EPUB novel(s) into Library.'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  Future<void> _importAndOpen(String filePath) async {
    setState(() => _isLoading = true);
    final book = await _explorerService.importSingleEpub(filePath);
    setState(() => _isLoading = false);

    if (mounted) {
      if (widget.onBookSelected != null) {
        widget.onBookSelected!(book);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickDirs = FileExplorerService.getQuickDirectories();

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Browse Files'),
        actions: [
          IconButton(
            tooltip: 'Import all EPUBs in this directory',
            icon: Icon(Icons.download_for_offline, color: EpilogueTheme.accent),
            onPressed: _importAllInCurrent,
          ),
        ],
      ),
      body: Column(
        children: [
          // Storage Permission Warning Banner if not granted
          if (!_hasStoragePermission)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_special, color: EpilogueTheme.dangerAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Storage permission required to read EPUBs on Android 11+.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EpilogueTheme.dangerAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('ENABLE'),
                  ),
                ],
              ),
            ),

          // Quick Jump chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(Icons.arrow_upward, size: 16, color: EpilogueTheme.textPrimary),
                  label: const Text('Up'),
                  onPressed: _goUp,
                  backgroundColor: EpilogueTheme.surface,
                  side: BorderSide(color: EpilogueTheme.border),
                ),
                const SizedBox(width: 8),
                for (final entry in quickDirs.entries) ...[
                  ActionChip(
                    avatar: Icon(
                      Icons.folder,
                      size: 16,
                      color: _currentPath == entry.value ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
                    ),
                    label: Text(entry.key),
                    onPressed: () => _navigateTo(entry.value),
                    backgroundColor: _currentPath == entry.value
                        ? const Color(0xFFE0F2FE)
                        : EpilogueTheme.surface,
                    side: BorderSide(
                      color: _currentPath == entry.value
                          ? EpilogueTheme.cyanAccent
                          : EpilogueTheme.border,
                    ),
                    labelStyle: TextStyle(
                      color: _currentPath == entry.value
                          ? EpilogueTheme.cyanAccent
                          : EpilogueTheme.textPrimary,
                      fontWeight: _currentPath == entry.value ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: EpilogueTheme.surfaceElevated,
            child: Text(
              _currentPath,
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary, fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (_statusMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _statusMsg,
                style: TextStyle(color: EpilogueTheme.greenAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),

          // File List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: EpilogueTheme.accent))
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open, size: 48, color: EpilogueTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No folders or EPUB files found here',
                              style: TextStyle(color: EpilogueTheme.textMuted, fontSize: 14),
                            ),
                            if (!_hasStoragePermission) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _requestPermission,
                                icon: const Icon(Icons.lock_open, size: 16),
                                label: const Text('Grant All Files Access'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: EpilogueTheme.border),
                        itemBuilder: (context, index) {
                          final entity = _entries[index];
                          final isDir = entity is Directory;
                          final name = entity.uri.pathSegments.isNotEmpty
                              ? (isDir
                                  ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
                                  : entity.uri.pathSegments.last)
                              : entity.path;
                          final isEpub = entity.path.toLowerCase().endsWith('.epub');

                          return ListTile(
                            tileColor: EpilogueTheme.surface,
                            leading: Icon(
                              isDir
                                  ? Icons.folder
                                  : (isEpub ? Icons.auto_stories : Icons.insert_drive_file),
                              color: isDir
                                  ? const Color(0xFFF59E0B)
                                  : (isEpub ? EpilogueTheme.cyanAccent : EpilogueTheme.textMuted),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: EpilogueTheme.textPrimary,
                                fontWeight: isEpub ? FontWeight.w700 : FontWeight.normal,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isEpub
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: EpilogueTheme.cyanAccent.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      'IMPORT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: EpilogueTheme.cyanAccent,
                                      ),
                                    ),
                                  )
                                : (isDir ? Icon(Icons.chevron_right, size: 18, color: EpilogueTheme.textMuted) : null),
                            onTap: () {
                              if (isDir) {
                                _navigateTo(entity.path);
                              } else if (isEpub) {
                                _importAndOpen(entity.path);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
