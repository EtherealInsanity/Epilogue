import 'package:flutter/material.dart';
import '../models/scenario.dart';
import '../models/bookmark.dart';
import '../models/book_highlight.dart';
import '../services/orv_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class ScenarioScreen extends StatefulWidget {
  final StorageService storageService;

  const ScenarioScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> with SingleTickerProviderStateMixin {
  late OrvService _orvService;
  late TabController _tabController;
  int _archiveFilterIndex = 0; // 0: All, 1: Highlights, 2: Bookmarks

  @override
  void initState() {
    super.initState();
    _orvService = OrvService(widget.storageService);
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _claim(Scenario scenario) async {
    await _orvService.claimScenario(scenario);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cleared "${scenario.title}" and earned +${scenario.coinReward} Coins!',
          ),
          backgroundColor: EpilogueTheme.accent,
        ),
      );
    }
  }

  Color _parseHighlightColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return EpilogueTheme.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.storageService.loadOrvState();
    final allScenarios = Scenario.defaultScenarios();
    final claimable = _orvService.evaluateScenarios();

    final mainScenarios = allScenarios.where((s) => s.type == ScenarioType.main).toList();
    final subScenarios = allScenarios.where((s) => s.type == ScenarioType.sub).toList();
    final hiddenScenarios = allScenarios.where((s) => s.type == ScenarioType.hidden).toList();

    final allBookmarks = widget.storageService.loadAllBookmarks();
    final allHighlights = widget.storageService.loadAllHighlights();

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Scenarios & Quests'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🪙 ${state.coins}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: EpilogueTheme.starGold,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: EpilogueTheme.accent,
          unselectedLabelColor: EpilogueTheme.textSecondary,
          indicatorColor: EpilogueTheme.accent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Main (${mainScenarios.length})'),
            Tab(text: 'Habits & Sub (${subScenarios.length})'),
            Tab(text: 'Bounty & Hidden (${hiddenScenarios.length})'),
            Tab(text: 'Archives & Notes (${allHighlights.length + allBookmarks.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScenarioList(mainScenarios, state.completedScenarioIds, claimable),
          _buildScenarioList(subScenarios, state.completedScenarioIds, claimable),
          _buildScenarioList(hiddenScenarios, state.completedScenarioIds, claimable),
          _buildArchivesView(allHighlights, allBookmarks),
        ],
      ),
    );
  }

  Widget _buildScenarioList(List<Scenario> list, List<String> completedIds, List<Scenario> claimable) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        final isCompleted = completedIds.contains(s.id);
        final canClaim = claimable.any((item) => item.id == s.id);
        final isLockedPrereq = s.requiredPrerequisiteScenarioId != null &&
            !completedIds.contains(s.requiredPrerequisiteScenarioId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: canClaim
                    ? EpilogueTheme.cyanAccent
                    : (isCompleted ? EpilogueTheme.greenAccent.withValues(alpha: 0.5) : EpilogueTheme.border),
                width: canClaim ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isLockedPrereq ? EpilogueTheme.textMuted : EpilogueTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.difficulty == 'Transcendent'
                              ? const Color(0xFFFEE2E2)
                              : (s.type == ScenarioType.main ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Rank ${s.difficulty}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s.difficulty == 'Transcendent'
                                ? EpilogueTheme.dangerAccent
                                : (s.type == ScenarioType.main ? EpilogueTheme.starGold : EpilogueTheme.cyanAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.objective,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLockedPrereq ? EpilogueTheme.textMuted : EpilogueTheme.textSecondary,
                    ),
                  ),
                  if (s.fableReward != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Fable Reward: ${s.fableReward}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EpilogueTheme.cyanAccent),
                    ),
                  ],
                  if (isLockedPrereq) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: EpilogueTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EpilogueTheme.border),
                      ),
                      child: Text(
                        '🔒 Prerequisite: Clear ${s.requiredPrerequisiteScenarioId}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EpilogueTheme.textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+${s.coinReward} Coins',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: EpilogueTheme.starGold,
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: EpilogueTheme.greenAccent,
                            ),
                          ),
                        )
                      else if (canClaim)
                        FilledButton(
                          onPressed: () => _claim(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: EpilogueTheme.cyanAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          child: const Text(
                            'CLAIM REWARD',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: EpilogueTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArchivesView(List<BookHighlight> highlights, List<Bookmark> bookmarks) {
    return Column(
      children: [
        // Sub-filter tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _filterChip(0, 'All (${highlights.length + bookmarks.length})'),
              const SizedBox(width: 8),
              _filterChip(1, 'Highlights (${highlights.length})'),
              const SizedBox(width: 8),
              _filterChip(2, 'Bookmarks (${bookmarks.length})'),
            ],
          ),
        ),
        Divider(color: EpilogueTheme.border),

        // List
        Expanded(
          child: Builder(
            builder: (context) {
              final showHighlights = _archiveFilterIndex == 0 || _archiveFilterIndex == 1;
              final showBookmarks = _archiveFilterIndex == 0 || _archiveFilterIndex == 2;

              if ((showHighlights && highlights.isEmpty) && (showBookmarks && bookmarks.isEmpty)) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 54, color: EpilogueTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No Archives or Highlights Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select text while reading to color-code and take notes,\nor tap the bookmark button in the reader.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (showHighlights) ...[
                    for (final hl in highlights) _buildHighlightCard(hl),
                  ],
                  if (showBookmarks) ...[
                    for (final bm in bookmarks) _buildBookmarkCard(bm),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(int index, String label) {
    final isSelected = _archiveFilterIndex == index;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : EpilogueTheme.textPrimary,
      ),
      backgroundColor: EpilogueTheme.surface,
      selectedColor: EpilogueTheme.accent,
      checkmarkColor: Colors.white,
      side: BorderSide(color: isSelected ? EpilogueTheme.accent : EpilogueTheme.border),
      onSelected: (_) {
        setState(() => _archiveFilterIndex = index);
      },
    );
  }

  Widget _buildHighlightCard(BookHighlight hl) {
    final color = _parseHighlightColor(hl.colorHex);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${hl.bookTitle} • ${hl.chapterTitle}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: EpilogueTheme.textMuted),
                  onPressed: () async {
                    await widget.storageService.deleteHighlight(hl.id);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: color, width: 3.5)),
              ),
              child: Text(
                '"${hl.selectedText}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: EpilogueTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),

            if (hl.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note, size: 16, color: EpilogueTheme.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hl.note,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EpilogueTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Bookmark bm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: EpilogueTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: EpilogueTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark, size: 16, color: EpilogueTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      bm.chapterTitle.isNotEmpty ? bm.chapterTitle : 'Chapter ${bm.chapterIndex + 1}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: EpilogueTheme.textMuted),
                  onPressed: () async {
                    await widget.storageService.deleteBookmark(bm.bookId, bm.id);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              bm.snippet,
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
