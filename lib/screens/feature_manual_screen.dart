import 'package:flutter/material.dart';
import '../theme/epilogue_theme.dart';

class ManualSection {
  final String title;
  final IconData icon;
  final String summary;
  final List<ManualTopic> topics;

  const ManualSection({
    required this.title,
    required this.icon,
    required this.summary,
    required this.topics,
  });
}

class ManualTopic {
  final String heading;
  final String content;
  final List<String> bulletPoints;
  final String? tip;

  const ManualTopic({
    required this.heading,
    required this.content,
    this.bulletPoints = const [],
    this.tip,
  });
}

class FeatureManualScreen extends StatefulWidget {
  const FeatureManualScreen({super.key});

  @override
  State<FeatureManualScreen> createState() => _FeatureManualScreenState();
}

class _FeatureManualScreenState extends State<FeatureManualScreen> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';

  static const List<ManualSection> sections = [
    ManualSection(
      title: 'The Reader Engine',
      icon: Icons.menu_book,
      summary: 'Tactile reading engine designed for 500+ chapter epics and fine typography.',
      topics: [
        ManualTopic(
          heading: 'Continuous Scroll vs. Paginated Mode',
          content: 'Epilogue features two distinct reading mechanics tailored to different preferences:',
          bulletPoints: [
            'Paginated Mode: Employs dynamic character budgeting to fit your screen exactly without vertical scrolling. Eliminates awkward cutoffs and bottom margin gaps.',
            'Continuous Scroll: Smooth vertical scrolling with continuous chapter loading. Ideal for fast web novel bingeing.',
          ],
          tip: 'Toggle between modes at any time from the bottom Reader Settings HUD.',
        ),
        ManualTopic(
          heading: 'Hardware Volume Key Paging',
          content: 'Turn pages effortlessly with your phone\'s physical Volume Up and Down buttons. Can be toggled on or off in Settings under Navigation & Controls.',
        ),
        ManualTopic(
          heading: 'Original EPUB CSS & Constellation Glow',
          content: 'Epilogue preserves original embedded stylesheets from your EPUBs while providing Star Stream atmospheric enhancements:',
          bulletPoints: [
            'Original Book Formatting: Keeps author headings, centered verse, and drop caps.',
            'Constellation CSS: Automatically detects brackets [...] in dialogue and styles them with glowing cyan borders and monospace font.',
          ],
        ),
        ManualTopic(
          heading: 'Pinch-to-Zoom Illustrations',
          content: 'Tap any book illustration to open the high-resolution lightbox with pinch-to-zoom, pan, and gallery inspection.',
        ),
      ],
    ),
    ManualSection(
      title: 'The 4th Wall',
      icon: Icons.shield,
      summary: 'Consciousness-shielding interface mode inspired by Omniscient Reader\'s Viewpoint.',
      topics: [
        ManualTopic(
          heading: 'What is The 4th Wall?',
          content: 'An exclusive skill that shields the reader from reality distortion and external sensory strain. In Epilogue, it converts the entire application into an immersive Midnight Blue (#0A192F) aesthetic with luminescent cyan borders.',
          bulletPoints: [
            'Activates a deeply restful midnight blue theme across all menus, library, settings, and reader.',
            'Triggers official Star Stream skill messages upon activation and deactivation.',
            'Customizable: Choose from curated midnight presets or supply your own hex color in Settings.',
          ],
          tip: 'Can be toggled from both Settings and the top-right shield button inside the Reader HUD.',
        ),
      ],
    ),
    ManualSection(
      title: 'Star Stream Lore & Progression',
      icon: Icons.auto_awesome,
      summary: '150+ canonical scenarios, constellation coin sponsorship, and fable progression.',
      topics: [
        ManualTopic(
          heading: 'Scenarios & Fables',
          content: 'As you read chapters, you clear canonical ORV scenarios (such as "Proof of Value", "Escape", and "Dark Castle").',
          bulletPoints: [
            'Track your cleared scenarios in the Scenarios tab.',
            'Earn Star Stream Coins from constellations monitoring your reading sessions.',
            'Inspect your constellation modifiers, fables, and attributes in the Attributes tab.',
          ],
        ),
        ManualTopic(
          heading: 'Constellation Sponsorship Reactions',
          content: 'Constellations like the Demon-like Judge of Fire, Secretive Plotter, and Prisoner of the Golden Headband will sponsor you with coins and atmospheric reactions as you read.',
        ),
      ],
    ),
    ManualSection(
      title: 'Archive & Library',
      icon: Icons.library_books,
      summary: 'Manage your book collection, shelves, metadata, and reading progress.',
      topics: [
        ManualTopic(
          heading: 'Smart Shelves',
          content: 'Organize your books across three standard shelves:',
          bulletPoints: [
            'Reading: Actively reading books with instant jump to last read position.',
            'Completed: Novels you have completed (reading progress ≥ 98%).',
            'Want to Read: Your backlog waiting for future reading.',
          ],
        ),
        ManualTopic(
          heading: 'Metadata & Cover Editing',
          content: 'Tap the three-dot menu on any book card to edit its Title, Author, or cover image. The app also automatically backfills missing covers on initial scan.',
        ),
        ManualTopic(
          heading: 'OPDS Catalog Browser',
          content: 'Connect to Calibre, Kavita, or public OPDS book catalogs directly within Epilogue to download books into your archive.',
        ),
      ],
    ),
    ManualSection(
      title: 'Cloud Sync & Backups',
      icon: Icons.cloud_sync,
      summary: 'Automated WebDAV synchronization and JSON snapshot backups.',
      topics: [
        ManualTopic(
          heading: 'WebDAV Cloud Synchronization',
          content: 'Keep your reading progress, bookmarks, and telemetry synchronized with your private Nextcloud, ownCloud, or WebDAV server:',
          bulletPoints: [
            'Smart Auto-Merge: Resolves multi-device sync without overwriting bookmarks.',
            'One-tap Pull and Push from Settings > Data Hub.',
          ],
        ),
        ManualTopic(
          heading: 'Offline JSON Snapshots',
          content: 'Export your entire library database, preferences, and Star Stream progression to a single portable JSON file at any time.',
        ),
      ],
    ),
    ManualSection(
      title: 'Epilogue Studio',
      icon: Icons.edit_note,
      summary: 'Professional-grade EPUB creator and editor built for retail distribution.',
      topics: [
        ManualTopic(
          heading: 'Tri-Mode Chapter Editor',
          content: 'Seamlessly switch between three authoring environments:',
          bulletPoints: [
            'Visual WYSIWYG: Write with a mobile formatting bar for headings, quotes, images, and drop caps.',
            'Markdown Mode: Distraction-free drafting with intuitive syntax.',
            'Raw XHTML/CSS Source Inspector: Directly view and modify tags and styles like desktop Sigil.',
          ],
        ),
        ManualTopic(
          heading: 'Retail-Ready Packaging (EPUB 3.3 + NCX)',
          content: 'Studio packages books to pass W3C epubcheck with 0 errors:',
          bulletPoints: [
            'Byte-exact uncompressed mimetype stored at byte offset 30.',
            'EPUB 3.3 nav.xhtml navigation with legacy EPUB 2 toc.ncx fallback for older Kindles.',
            'Built-in Pre-Flight Linter to catch broken links, unclosed tags, and metadata errors.',
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentSection = sections[_selectedCategoryIndex];

    final filteredTopics = _searchQuery.trim().isEmpty
        ? currentSection.topics
        : sections
            .expand((s) => s.topics)
            .where((t) =>
                t.heading.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.content.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Epilogue Grimoire & Manual'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: TextStyle(color: EpilogueTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search manual topics...',
                hintStyle: TextStyle(color: EpilogueTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: EpilogueTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EpilogueTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EpilogueTheme.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Categories Horizontal Chips
          if (_searchQuery.trim().isEmpty)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: sections.length,
                itemBuilder: (ctx, idx) {
                  final sec = sections[idx];
                  final isSelected = idx == _selectedCategoryIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sec.icon,
                            size: 14,
                            color: isSelected ? Colors.white : EpilogueTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(sec.title),
                        ],
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : EpilogueTheme.textPrimary,
                      ),
                      selectedColor: EpilogueTheme.accent,
                      backgroundColor: EpilogueTheme.surface,
                      side: BorderSide(
                        color: isSelected ? EpilogueTheme.accent : EpilogueTheme.border,
                      ),
                      onSelected: (_) => setState(() => _selectedCategoryIndex = idx),
                    ),
                  );
                },
              ),
            ),

          Divider(color: EpilogueTheme.border, height: 1),

          // Content List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTopics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, idx) {
                final topic = filteredTopics[idx];
                return Card(
                  color: EpilogueTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: EpilogueTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.heading,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: EpilogueTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          topic.content,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: EpilogueTheme.textSecondary,
                          ),
                        ),
                        if (topic.bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...topic.bulletPoints.map(
                            (bp) => Padding(
                              padding: const EdgeInsets.only(left: 6, bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: EpilogueTheme.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bp,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: EpilogueTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (topic.tip != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: EpilogueTheme.cyanAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: EpilogueTheme.cyanAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline, size: 16, color: EpilogueTheme.cyanAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    topic.tip!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: EpilogueTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
