import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_explorer_service.dart';
import '../services/opds_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class OpdsBrowserScreen extends StatefulWidget {
  final StorageService storageService;

  const OpdsBrowserScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<OpdsBrowserScreen> createState() => _OpdsBrowserScreenState();
}

class _OpdsBrowserScreenState extends State<OpdsBrowserScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FileExplorerService _explorerService;

  // OPDS State
  List<OpdsServerProfile> _profiles = [];
  OpdsServerProfile? _selectedProfile;
  List<OpdsEntry> _currentEntries = [];
  final List<String> _navigationHistory = [];
  bool _isLoading = false;
  String _currentCatalogUrl = '';

  // Web Downloader State
  final _urlController = TextEditingController();
  final _customFilenameController = TextEditingController();
  bool _isDownloading = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _explorerService = FileExplorerService(widget.storageService);
    _profiles = OpdsService.defaultProfiles();
    if (_profiles.isNotEmpty) {
      _selectedProfile = _profiles.first;
      _loadCatalog(_selectedProfile!.url);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _customFilenameController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog(String url) async {
    setState(() {
      _isLoading = true;
      _currentCatalogUrl = url;
    });

    final entries = await OpdsService.fetchCatalog(
      url,
      username: _selectedProfile?.username,
      password: _selectedProfile?.password,
    );

    if (mounted) {
      setState(() {
        _currentEntries = entries;
        _isLoading = false;
      });
    }
  }

  void _navigateToSubCatalog(String url) {
    _navigationHistory.add(_currentCatalogUrl);
    _loadCatalog(url);
  }

  void _navigateBack() {
    if (_navigationHistory.isNotEmpty) {
      final prev = _navigationHistory.removeLast();
      _loadCatalog(prev);
    }
  }

  String _getTargetLibraryFolder() {
    final config = widget.storageService.loadConfig();
    if (config.libraryFolderPath != null && Directory(config.libraryFolderPath!).existsSync()) {
      return config.libraryFolderPath!;
    }
    return '${FileExplorerService.rootStoragePath}/Documents/Books';
  }

  Future<void> _downloadOpdsBook(OpdsEntry entry) async {
    if (entry.epubDownloadUrl == null) return;

    final targetFolder = _getTargetLibraryFolder();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${entry.title}"...'),
        backgroundColor: EpilogueTheme.cyanAccent,
      ),
    );

    final file = await OpdsService.downloadEpub(
      downloadUrl: entry.epubDownloadUrl!,
      targetFolderPath: targetFolder,
      customFilename: '${entry.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.epub',
    );

    if (file != null && mounted) {
      await _explorerService.importSingleEpub(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added "${entry.title}" to Library!'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  Future<void> _downloadDirectUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid HTTP/HTTPS URL'),
          backgroundColor: EpilogueTheme.dangerAccent,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Downloading EPUB from web link...';
    });

    final targetFolder = _getTargetLibraryFolder();
    final customName = _customFilenameController.text.trim().isNotEmpty
        ? _customFilenameController.text.trim()
        : null;

    final file = await OpdsService.downloadEpub(
      downloadUrl: url,
      targetFolderPath: targetFolder,
      customFilename: customName,
    );

    setState(() {
      _isDownloading = false;
      _downloadStatus = '';
    });

    if (file != null && mounted) {
      await _explorerService.importSingleEpub(file.path);
      if (!mounted) return;
      _urlController.clear();
      _customFilenameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded and added "${file.uri.pathSegments.last}" to Library!'),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download EPUB file. Check URL or connection.'),
          backgroundColor: EpilogueTheme.dangerAccent,
        ),
      );
    }
  }

  void _showAddServerDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'http://192.168.1.');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: EpilogueTheme.border),
        ),
        title: const Text('Add OPDS / Calibre Server'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Server Name (e.g. Home Calibre)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'OPDS URL (e.g. http://192.168.1.10:8080/opds)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username (Optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: EpilogueTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty && urlCtrl.text.trim().isNotEmpty) {
                final newProf = OpdsServerProfile(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                  username: userCtrl.text.trim().isNotEmpty ? userCtrl.text.trim() : null,
                  password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                );
                setState(() {
                  _profiles.add(newProf);
                  _selectedProfile = newProf;
                });
                Navigator.pop(ctx);
                _loadCatalog(newProf.url);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.accent),
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Online Catalogs & Downloader'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: EpilogueTheme.accent,
          unselectedLabelColor: EpilogueTheme.textSecondary,
          indicatorColor: EpilogueTheme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'OPDS Catalogs'),
            Tab(icon: Icon(Icons.download), text: 'Web URL Downloader'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpdsTab(),
          _buildWebDownloaderTab(),
        ],
      ),
    );
  }

  Widget _buildOpdsTab() {
    return Column(
      children: [
        // Profile Selector & Add button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: EpilogueTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<OpdsServerProfile>(
                    value: _selectedProfile,
                    isExpanded: true,
                    items: _profiles.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p != null) {
                        setState(() {
                          _selectedProfile = p;
                          _navigationHistory.clear();
                        });
                        _loadCatalog(p.url);
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add Calibre or OPDS Server',
                icon: const Icon(Icons.add_circle, color: EpilogueTheme.accent),
                onPressed: _showAddServerDialog,
              ),
            ],
          ),
        ),
        if (_navigationHistory.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: EpilogueTheme.surfaceElevated,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: _navigateBack,
                ),
                const SizedBox(width: 8),
                const Text('Back to parent catalog', style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary)),
              ],
            ),
          ),
        const Divider(height: 1, color: EpilogueTheme.border),

        // Entries List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: EpilogueTheme.accent))
              : _currentEntries.isEmpty
                  ? const Center(
                      child: Text('No books or catalogs found at this address.', style: TextStyle(color: EpilogueTheme.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _currentEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: EpilogueTheme.border),
                      itemBuilder: (context, index) {
                        final entry = _currentEntries[index];
                        if (entry.isDirectory && entry.catalogUrl != null) {
                          return ListTile(
                            leading: const Icon(Icons.folder, color: EpilogueTheme.accent),
                            title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _navigateToSubCatalog(entry.catalogUrl!),
                          );
                        }
                        return ListTile(
                          leading: entry.coverUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    entry.coverUrl!,
                                    width: 40,
                                    height: 55,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.book, color: EpilogueTheme.accent),
                                  ),
                                )
                              : const Icon(Icons.book, color: EpilogueTheme.accent),
                          title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(entry.author, style: const TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary)),
                          trailing: IconButton(
                            tooltip: 'Download to Library',
                            icon: const Icon(Icons.download_for_offline, color: EpilogueTheme.cyanAccent),
                            onPressed: () => _downloadOpdsBook(entry),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildWebDownloaderTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Download EPUB from Direct Web Link',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: EpilogueTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Paste any direct URL to a webnovel or light novel EPUB. It will be downloaded directly into your library folder and indexed automatically.',
          style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'EPUB Direct Download URL',
            hintText: 'https://example.com/novel.epub',
            filled: true,
            fillColor: EpilogueTheme.surface,
            prefixIcon: const Icon(Icons.link, color: EpilogueTheme.accent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _customFilenameController,
          decoration: InputDecoration(
            labelText: 'Custom Filename (Optional)',
            hintText: 'My_Novel.epub',
            filled: true,
            fillColor: EpilogueTheme.surface,
            prefixIcon: const Icon(Icons.edit_note, color: EpilogueTheme.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        if (_isDownloading)
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(color: EpilogueTheme.accent),
                const SizedBox(height: 12),
                Text(_downloadStatus, style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary)),
              ],
            ),
          )
        else
          FilledButton.icon(
            onPressed: _downloadDirectUrl,
            icon: const Icon(Icons.download),
            label: const Text('DOWNLOAD & ADD TO LIBRARY'),
            style: FilledButton.styleFrom(
              backgroundColor: EpilogueTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}
