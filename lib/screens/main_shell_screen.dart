import 'dart:io';
import 'package:flutter/material.dart';
import '../config/reader_config.dart';
import '../models/orv_state.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';
import 'attribute_window_screen.dart';
import 'library_screen.dart';
import 'scenario_screen.dart';
import 'settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  final StorageService storageService;

  const MainShellScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  late ReaderConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.storageService.loadConfig();
  }

  void _onConfigChanged(ReaderConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
  }

  Widget _buildAvatarIcon(OrvState state, bool isSelected) {
    if (state.customAvatarPath != null && File(state.customAvatarPath!).existsSync()) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? EpilogueTheme.accent : EpilogueTheme.borderStrong,
            width: isSelected ? 2.0 : 1.0,
          ),
          image: DecorationImage(
            image: FileImage(File(state.customAvatarPath!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? EpilogueTheme.accent : EpilogueTheme.surfaceElevated,
        border: Border.all(
          color: isSelected ? EpilogueTheme.accent : EpilogueTheme.border,
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 16,
          color: isSelected ? Colors.white : EpilogueTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRuneIcon(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Text(
        'ᚱ', // Raidho Rune - the Journey & Quest
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1.0,
          color: isSelected ? EpilogueTheme.accent : EpilogueTheme.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orvState = widget.storageService.loadOrvState();

    final screens = [
      LibraryScreen(
        storageService: widget.storageService,
        config: _config,
        onSettingsChanged: () => setState(() => _config = widget.storageService.loadConfig()),
      ),
      ScenarioScreen(storageService: widget.storageService),
      AttributeWindowScreen(storageService: widget.storageService),
      SettingsScreen(
        initialConfig: _config,
        storageService: widget.storageService,
        onConfigChanged: _onConfigChanged,
      ),
    ];

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_config.uiScale),
      ),
      child: Theme(
        data: EpilogueTheme.lightTheme(),
        child: Scaffold(
          backgroundColor: EpilogueTheme.background,
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: EpilogueTheme.surface,
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFFE2E8F0),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined, size: 24),
              selectedIcon: Icon(Icons.auto_awesome, size: 24, color: EpilogueTheme.accent),
              label: 'Archive',
            ),
            NavigationDestination(
              icon: _buildRuneIcon(false),
              selectedIcon: _buildRuneIcon(true),
              label: 'Scenarios',
            ),
            NavigationDestination(
              icon: _buildAvatarIcon(orvState, false),
              selectedIcon: _buildAvatarIcon(orvState, true),
              label: 'Attributes',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_suggest_outlined, size: 24),
              selectedIcon: Icon(Icons.settings_suggest, size: 24, color: EpilogueTheme.accent),
              label: 'Settings',
            ),
          ],
        ),
      ),
    ),
  );
}
}
