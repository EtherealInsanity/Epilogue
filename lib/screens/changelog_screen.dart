import 'package:flutter/material.dart';
import '../theme/epilogue_theme.dart';

class ChangelogItem {
  final String version;
  final String date;
  final String title;
  final bool isLatest;
  final List<String> features;
  final List<String> fixes;

  const ChangelogItem({
    required this.version,
    required this.date,
    required this.title,
    this.isLatest = false,
    required this.features,
    required this.fixes,
  });
}

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const List<ChangelogItem> changelogs = [
    ChangelogItem(
      version: 'v2.0.4',
      date: 'October 2026',
      title: 'Real-Time Settings, Streak Restore & Quality of Life',
      isLatest: true,
      features: [
        'Real-Time Reactive Settings: Switches, sliders, theme chips, and controls inside categories update instantly on the fly without needing to back out and re-enter.',
        'Reader TOC Auto-Scroll: Opening Table of Contents in reader mode automatically and smoothly scrolls to the chapter currently being read.',
        'Reading Streak Restore (🪙 10K Coins): Missed yesterday\'s scenario? Incarnations can now spend 10,000 Coins from the Star Stream to repair broken streaks.',
        'Manual Reading Streak Import: Enter your historical streak days directly into the Manual Reading Telemetry import dialog.',
        'Cleaned Attributes Screen: Reading Telemetry & Streaks moved up directly beneath the Incarnation card, with Modifiers, Attributes, and Fables collapsed by default.',
        'Toggleable Epilogue Studio: Studio is now off by default and toggleable via Settings > Reading Engine & Controls, keeping the navigation bar clean for pure reading.',
        'Polished 4th Wall Visuals: Upgraded 4th Wall shield card, palette chips with color indicator swatches, and illuminated reader mode action button.',
        'Default Large Cover Grid: Library view mode now defaults to large cover display cards.',
        'Community & Bug Reporting: One-tap access to the Discord community, GitHub bug/issue tracker, and developer profile.',
      ],
      fixes: [
        'Completely removed legacy online catalog / OPDS dependencies for faster startup and zero bloat.',
        'Fixed subpage route rebuild desynchronization in settings categories.',
        'Resolved unreadable color contrast on 4th Wall shield chips and descriptions.',
      ],
    ),
    ChangelogItem(
      version: 'v2.0.3',
      date: 'October 2026',
      title: 'Epilogue Studio & The 4th Wall',
      isLatest: false,
      features: [
        'Epilogue Studio: Full-featured EPUB 3.3 and EPUB 2 NCX authoring and editing suite built directly into Android.',
        'Tri-Mode Chapter Editor: Seamlessly toggle between Visual WYSIWYG, Markdown, and Raw XHTML/CSS Source Inspector with sticky formatting toolbar.',
        'Professional Genre Templates: Pre-configured styling for Classic Novels, Light Novels / Fantasy, and Non-Fiction works.',
        'Pre-Flight EPUB Linter: Built-in validator checking tag closures, XHTML strictness, and UUID metadata with 1-click auto-repair.',
        'Spine Hierarchy Manager: Drag-and-drop chapter reordering with live word count tracking and duplicate detection.',
        'The 4th Wall Mode: System-wide Midnight Blue UI (#0A192F or custom hex) with authentic Star Stream skill notifications.',
        'Dynamic Theming Engine: Seamless switching across Paper Light, Sepia Warm, Slate Gray, and OLED Dark palettes.',
        'Sub-200ms JIT Reader Engine: Sliding-window loading eliminating parse delays on 500+ chapter epics.',
        'The Epilogue Grimoire: Searchable in-app feature manual and architectural guide.',
        'Automatic Update Checker: Direct integration with GitHub Releases for 1-tap verification and updates.',
      ],
      fixes: [],
    ),
    ChangelogItem(
      version: 'v1.0.0',
      date: 'October 2026',
      title: 'Genesis Release - Star Stream Reader',
      isLatest: false,
      features: [
        'Modern Reader Engine: Dual continuous scroll and paginated reading modes with character budgeting.',
        'Star Stream Progression: 150+ canonical scenarios, constellation sponsorship, coins economy, modifiers, and fables.',
        'Touch-TUI & Retro Aesthetics: CRT scanline fragment shader and tactile haptics.',
        'Cloud Sync & Backup: Two-way WebDAV synchronization with Nextcloud/ownCloud and JSON snapshot exports.',
        'Rich EPUB CSS: Full preservation of embedded chapter styling, centered text, blockquotes, and drop caps.',
        'Library Shelving: Reading, Completed, and Want to Read shelves with reading telemetry tracking.',
      ],
      fixes: [
        'Fixed bottom margin blanking on tall screen aspect ratios.',
        'Resolved chapter splitting HTML tag corruption.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Update Changelog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: changelogs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (ctx, index) {
          final item = changelogs[index];
          return Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: item.isLatest ? EpilogueTheme.cyanAccent : EpilogueTheme.border,
                width: item.isLatest ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isLatest
                              ? EpilogueTheme.cyanAccent.withValues(alpha: 0.15)
                              : EpilogueTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isLatest
                                ? EpilogueTheme.cyanAccent
                                : EpilogueTheme.border,
                          ),
                        ),
                        child: Text(
                          item.version,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: item.isLatest
                                ? EpilogueTheme.cyanAccent
                                : EpilogueTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: EpilogueTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (item.isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: EpilogueTheme.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: EpilogueTheme.greenAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: EpilogueTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (item.features.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: EpilogueTheme.cyanAccent),
                        const SizedBox(width: 6),
                        Text(
                          'NEW FEATURES & UPGRADES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: EpilogueTheme.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...item.features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: EpilogueTheme.cyanAccent, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(fontSize: 12, height: 1.4, color: EpilogueTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (item.fixes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.build_circle, size: 14, color: EpilogueTheme.greenAccent),
                        const SizedBox(width: 6),
                        Text(
                          'FIXES & OPTIMIZATIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: EpilogueTheme.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...item.fixes.map(
                      (fix) => Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: EpilogueTheme.greenAccent, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                fix,
                                style: TextStyle(fontSize: 12, height: 1.4, color: EpilogueTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
