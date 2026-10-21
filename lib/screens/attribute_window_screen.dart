import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/orv_canon_item.dart';
import '../models/orv_state.dart';
import '../services/orv_service.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';
import '../widgets/dialog_manual_reading_import.dart';
import 'retrocognition_screen.dart';

class AttributeWindowScreen extends StatefulWidget {
  final StorageService storageService;

  const AttributeWindowScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<AttributeWindowScreen> createState() => _AttributeWindowScreenState();
}

class _AttributeWindowScreenState extends State<AttributeWindowScreen> {
  late OrvService _orvService;

  bool _fablesCollapsed = true;
  bool _attributesCollapsed = true;
  bool _modifiersCollapsed = true;
  String _fablesSearch = '';
  String _attributesSearch = '';
  String _modifiersSearch = '';
  final TextEditingController _fablesSearchCtrl = TextEditingController();
  final TextEditingController _attributesSearchCtrl = TextEditingController();
  final TextEditingController _modifiersSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orvService = OrvService(widget.storageService);
  }

  @override
  void dispose() {
    _fablesSearchCtrl.dispose();
    _attributesSearchCtrl.dispose();
    _modifiersSearchCtrl.dispose();
    super.dispose();
  }

  void _showEditIncarnationNameDialog(OrvState state) {
    final ctrl = TextEditingController(text: state.incarnationName);
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
            Icon(Icons.badge, color: EpilogueTheme.cyanAccent),
            const SizedBox(width: 10),
            const Text('Set Incarnation Name'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your official name registered in the Star Stream.',
              style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Incarnation Name',
                hintText: 'e.g. Kim Dokja, Dusk, Yoo Joonghyuk',
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
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                await _orvService.setIncarnationName(newName);
                if (mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _openManualImportDialog() {
    showDialog(
      context: context,
      builder: (_) => DialogManualReadingImport(
        storageService: widget.storageService,
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _openRetrocognition() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetrocognitionScreen(storageService: widget.storageService),
      ),
    );
    if (mounted) setState(() {});
  }

  void _restoreStreak(OrvState state) async {
    const cost = 10000;
    if (state.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[System: Insufficient coins. You need 10,000 coins to restore your reading streak. Current: ${state.coins}]'),
          backgroundColor: EpilogueTheme.dangerAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpilogueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EpilogueTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restore Reading Streak?'),
          ],
        ),
        content: Text(
          'Spend 10,000 coins to repair yesterday\'s broken scenario and immediately resume your reading streak?\n\nRemaining coins: ${state.coins - cost}',
          style: TextStyle(fontSize: 13, color: EpilogueTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.starGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESTORE (🪙 10K)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _orvService.spendCoins(cost);
      if (success) {
        await widget.storageService.restoreBrokenStreak();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('[The constellation \'Demon-like Judge of Fire\' rejoices at your dedication. Your reading streak has been restored!]'),
              backgroundColor: EpilogueTheme.accent,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickCustomAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final originalPath = result.files.single.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final ext = originalPath.split('.').last;
        final targetPath = '${appDir.path}/custom_avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await File(originalPath).copy(targetPath);

        final state = widget.storageService.loadOrvState();
        final updated = state.copyWith(customAvatarPath: targetPath);
        await widget.storageService.saveOrvState(updated);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load avatar image: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
    }
  }

  void _showAvatarPickerSheet(OrvState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avatar & Incarnation Emblem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: EpilogueTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload a custom image or select a preset avatar.',
                style: TextStyle(fontSize: 13, color: EpilogueTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.upload_file, color: EpilogueTheme.cyanAccent),
                ),
                title: Text(
                  'Upload from Device Storage',
                  style: TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                ),
                subtitle: const Text('Pick any PNG, JPG, or WEBP image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomAvatar();
                },
              ),
              Divider(color: EpilogueTheme.border),
              const SizedBox(height: 8),
              Text(
                'Preset Incarnations',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EpilogueTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _presetAvatarOption('dokja', 'Dokja', Icons.auto_stories, Colors.blue),
                  _presetAvatarOption('joonghyuk', 'Joonghyuk', Icons.shield, Colors.black87),
                  _presetAvatarOption('sooyoung', 'Sooyoung', Icons.edit_note, Colors.purple),
                  _presetAvatarOption('bihyung', 'Bihyung', Icons.live_tv, Colors.amber.shade800),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _presetAvatarOption(String id, String label, IconData icon, Color color) {
    final state = widget.storageService.loadOrvState();
    final isSelected = state.customAvatarPath == null && state.presetAvatarId == id;

    return InkWell(
      onTap: () async {
        final updated = state.copyWith(customAvatarPath: null, presetAvatarId: id);
        await widget.storageService.saveOrvState(updated);
        if (mounted) {
          setState(() {});
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? EpilogueTheme.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? EpilogueTheme.accent : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: EpilogueTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(CanonGrade grade) {
    switch (grade) {
      case CanonGrade.general:
        return const Color(0xFF64748B);
      case CanonGrade.narrative:
        return EpilogueTheme.cyanAccent;
      case CanonGrade.myth:
        return EpilogueTheme.starGold;
      case CanonGrade.transcendent:
        return const Color(0xFFEF4444);
    }
  }

  Widget _buildGradeBadge(CanonGrade grade) {
    final color = _getGradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        grade.shortLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showModifierSelectorSheet(OrvState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final liveState = widget.storageService.loadOrvState();
            return DraggableScrollableSheet(
              initialChildSize: 0.80,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: EpilogueTheme.borderStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Constellation Modifiers',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: EpilogueTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🪙 ${liveState.coins} COINS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: EpilogueTheme.starGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'General, Narrative, and Myth titles cost coins. Transcendent ■■ titles must be earned through legendary Scenarios.',
                            style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: EpilogueTheme.border),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: OrvService.allModifiersWithTiers.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: EpilogueTheme.border),
                        itemBuilder: (context, index) {
                          final item = OrvService.allModifiersWithTiers[index];
                          final isEquipped = liveState.constellationModifier == item.name;
                          final isUnlocked = liveState.unlockedModifiers.contains(item.name);

                          return ListTile(
                            leading: Icon(
                              isEquipped ? Icons.star : (isUnlocked ? Icons.star_border : Icons.lock_outline),
                              color: isEquipped
                                  ? EpilogueTheme.starGold
                                  : (isUnlocked ? EpilogueTheme.accent : EpilogueTheme.textMuted),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w600,
                                      color: isUnlocked ? EpilogueTheme.textPrimary : EpilogueTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildGradeBadge(item.grade),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                !isUnlocked && !item.isPurchasable
                                    ? '★ Unlocked via Scenario: ${item.unlockScenarioId}'
                                    : (item.description ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !isUnlocked && !item.isPurchasable
                                      ? EpilogueTheme.cyanAccent
                                      : EpilogueTheme.textSecondary,
                                  fontWeight: !isUnlocked && !item.isPurchasable ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            trailing: isEquipped
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'EQUIPPED',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.greenAccent),
                                    ),
                                  )
                                : isUnlocked
                                    ? OutlinedButton(
                                        onPressed: () async {
                                          await _orvService.equipModifier(item.name);
                                          setSheetState(() {});
                                          if (mounted) setState(() {});
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          side: BorderSide(color: EpilogueTheme.accent),
                                        ),
                                        child: Text('EQUIP', style: TextStyle(color: EpilogueTheme.accent, fontSize: 11)),
                                      )
                                    : !item.isPurchasable
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('LOCKED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EpilogueTheme.dangerAccent)),
                                          )
                                        : TextButton.icon(
                                            onPressed: liveState.coins >= item.coinCost
                                                ? () async {
                                                    final success = await _orvService.unlockModifierWithCoins(item.name);
                                                    if (success) {
                                                      setSheetState(() {});
                                                      if (mounted) setState(() {});
                                                    }
                                                  }
                                                : null,
                                            icon: const Icon(Icons.lock_open, size: 14),
                                            label: Text('${item.coinCost} 🪙', style: const TextStyle(fontSize: 11)),
                                          ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFablesManagerSheet(OrvState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final liveState = widget.storageService.loadOrvState();
            return DraggableScrollableSheet(
              initialChildSize: 0.80,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: EpilogueTheme.borderStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fables & Giant Stories',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🪙 ${liveState.coins} COINS',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: EpilogueTheme.starGold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Equip your active Fable or unlock legendary stories from the Star Stream.',
                            style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: EpilogueTheme.border),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: OrvService.allFablesWithTiers.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: EpilogueTheme.border),
                        itemBuilder: (context, index) {
                          final item = OrvService.allFablesWithTiers[index];
                          final isEquipped = liveState.equippedFable == item.name;
                          final isAcquired = liveState.acquiredFables.contains(item.name);

                          return ListTile(
                            leading: Icon(
                              isEquipped ? Icons.auto_awesome : (isAcquired ? Icons.menu_book : Icons.lock_outline),
                              color: isEquipped
                                  ? EpilogueTheme.starGold
                                  : (isAcquired ? EpilogueTheme.accent : EpilogueTheme.textMuted),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w600,
                                      color: isAcquired ? EpilogueTheme.textPrimary : EpilogueTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildGradeBadge(item.grade),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                !isAcquired && !item.isPurchasable
                                    ? '★ Unlocked via Scenario: ${item.unlockScenarioId}'
                                    : (item.description ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !isAcquired && !item.isPurchasable ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
                                  fontWeight: !isAcquired && !item.isPurchasable ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            trailing: isEquipped
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('ACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.greenAccent)),
                                  )
                                : isAcquired
                                    ? OutlinedButton(
                                        onPressed: () async {
                                          await _orvService.equipFable(item.name);
                                          setSheetState(() {});
                                          if (mounted) setState(() {});
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          side: BorderSide(color: EpilogueTheme.accent),
                                        ),
                                        child: Text('EQUIP', style: TextStyle(color: EpilogueTheme.accent, fontSize: 11)),
                                      )
                                    : !item.isPurchasable
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('LOCKED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EpilogueTheme.dangerAccent)),
                                          )
                                        : TextButton.icon(
                                            onPressed: liveState.coins >= item.coinCost
                                                ? () async {
                                                    final success = await _orvService.unlockFableWithCoins(item.name);
                                                    if (success) {
                                                      setSheetState(() {});
                                                      if (mounted) setState(() {});
                                                    }
                                                  }
                                                : null,
                                            icon: const Icon(Icons.lock_open, size: 14),
                                            label: Text('${item.coinCost} 🪙', style: const TextStyle(fontSize: 11)),
                                          ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAttributesManagerSheet(OrvState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpilogueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final liveState = widget.storageService.loadOrvState();
            return DraggableScrollableSheet(
              initialChildSize: 0.80,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: EpilogueTheme.borderStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Incarnation Attributes',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🪙 ${liveState.coins} COINS',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: EpilogueTheme.starGold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Equip your primary Incarnation Attribute or unlock canon attributes with coins.',
                            style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: EpilogueTheme.border),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: OrvService.allAttributesWithTiers.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: EpilogueTheme.border),
                        itemBuilder: (context, index) {
                          final item = OrvService.allAttributesWithTiers[index];
                          final isEquipped = liveState.equippedAttribute == item.name;
                          final isUnlocked = liveState.unlockedAttributes.contains(item.name);

                          return ListTile(
                            leading: Icon(
                              isEquipped ? Icons.bolt : (isUnlocked ? Icons.shield_outlined : Icons.lock_outline),
                              color: isEquipped
                                  ? EpilogueTheme.cyanAccent
                                  : (isUnlocked ? EpilogueTheme.accent : EpilogueTheme.textMuted),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w600,
                                      color: isUnlocked ? EpilogueTheme.textPrimary : EpilogueTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildGradeBadge(item.grade),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                !isUnlocked && !item.isPurchasable
                                    ? '★ Unlocked via Scenario: ${item.unlockScenarioId}'
                                    : (item.description ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !isUnlocked && !item.isPurchasable ? EpilogueTheme.cyanAccent : EpilogueTheme.textSecondary,
                                  fontWeight: !isUnlocked && !item.isPurchasable ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            trailing: isEquipped
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('EQUIPPED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EpilogueTheme.greenAccent)),
                                  )
                                : isUnlocked
                                    ? OutlinedButton(
                                        onPressed: () async {
                                          await _orvService.equipAttribute(item.name);
                                          setSheetState(() {});
                                          if (mounted) setState(() {});
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          side: BorderSide(color: EpilogueTheme.accent),
                                        ),
                                        child: Text('EQUIP', style: TextStyle(color: EpilogueTheme.accent, fontSize: 11)),
                                      )
                                    : !item.isPurchasable
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('LOCKED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EpilogueTheme.dangerAccent)),
                                          )
                                        : TextButton.icon(
                                            onPressed: liveState.coins >= item.coinCost
                                                ? () async {
                                                    final success = await _orvService.unlockAttributeWithCoins(item.name);
                                                    if (success) {
                                                      setSheetState(() {});
                                                      if (mounted) setState(() {});
                                                    }
                                                  }
                                                : null,
                                            icon: const Icon(Icons.lock_open, size: 14),
                                            label: Text('${item.coinCost} 🪙', style: const TextStyle(fontSize: 11)),
                                          ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarWidget(OrvState state) {
    if (state.customAvatarPath != null && File(state.customAvatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: FileImage(File(state.customAvatarPath!)),
      );
    }

    IconData icon = Icons.person;
    Color color = EpilogueTheme.accent;
    if (state.presetAvatarId == 'dokja') {
      icon = Icons.auto_stories;
      color = EpilogueTheme.cyanAccent;
    } else if (state.presetAvatarId == 'joonghyuk') {
      icon = Icons.shield;
      color = EpilogueTheme.accent;
    } else if (state.presetAvatarId == 'sooyoung') {
      icon = Icons.edit_note;
      color = Colors.purple;
    } else if (state.presetAvatarId == 'bihyung') {
      icon = Icons.live_tv;
      color = EpilogueTheme.starGold;
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, size: 38, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.storageService.loadOrvState();
    final books = widget.storageService.loadBooks();

    final totalSeconds = widget.storageService.getTotalLibraryReadingSeconds() + state.manualPastSeconds;
    final totalWords = widget.storageService.getTotalLibraryWordsRead() + state.manualPastWords;
    final totalPages = widget.storageService.getTotalLibraryPagesRead() + state.manualPastPages;
    final completedBooks = books.where((b) =>
        b.totalChapters > 0 &&
        b.lastReadChapterIndex >= b.totalChapters - 1 &&
        b.lastReadProgressPercent > 95.0).length + state.manualPastVolumes;
    final wpm = widget.storageService.getAverageReadingWpm();
    final currentStreak = widget.storageService.getCurrentStreakDays();
    final longestStreak = widget.storageService.getLongestStreakDays();
    final todayStats = widget.storageService.getTodayStats();

    final hours = (totalSeconds / 3600).toStringAsFixed(1);
    final wordsFormatted = totalWords >= 1000000
        ? '${(totalWords / 1000000).toStringAsFixed(1)}M'
        : (totalWords >= 1000 ? '${(totalWords / 1000).toStringAsFixed(1)}K' : '$totalWords');

    return Scaffold(
      backgroundColor: EpilogueTheme.background,
      appBar: AppBar(
        title: const Text('Attributes'),
        actions: [
          IconButton(
            tooltip: 'Retrocognition (Sync Past Progress)',
            icon: Icon(Icons.history_edu, color: EpilogueTheme.starGold),
            onPressed: _openRetrocognition,
          ),
          IconButton(
            tooltip: 'Import past reading telemetry',
            icon: Icon(Icons.add_chart, color: EpilogueTheme.textPrimary),
            onPressed: _openManualImportDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Profile & Avatar Card
          Card(
            color: EpilogueTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: EpilogueTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPickerSheet(state),
                    child: Stack(
                      children: [
                        _buildAvatarWidget(state),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: EpilogueTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🪙 ${state.coins} COINS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: EpilogueTheme.starGold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showAvatarPickerSheet(state),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Avatar', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.incarnationName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: EpilogueTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, size: 15, color: EpilogueTheme.accent),
                              tooltip: 'Edit Incarnation Name',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showEditIncarnationNameDialog(state),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.constellationModifier.isNotEmpty
                              ? state.constellationModifier
                              : '[ Incarnation ]',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: state.constellationModifier.isNotEmpty
                                ? EpilogueTheme.cyanAccent
                                : EpilogueTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Attribute: ${state.equippedAttribute.isNotEmpty ? state.equippedAttribute : 'None'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: state.equippedAttribute.isNotEmpty ? EpilogueTheme.cyanAccent : EpilogueTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fable: ${state.equippedFable.isNotEmpty ? '[ ${state.equippedFable} ]' : 'None'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: state.equippedFable.isNotEmpty ? EpilogueTheme.starGold : EpilogueTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Retrocognition Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EpilogueTheme.starGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.history_edu, color: EpilogueTheme.starGold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Retrocognition (과거 읽기 회상)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                      Text('Import past novel chapters to instantly calculate words, hours, and clear scenarios.',
                          style: TextStyle(fontSize: 11, color: EpilogueTheme.textSecondary)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _openRetrocognition,
                  style: FilledButton.styleFrom(backgroundColor: EpilogueTheme.starGold),
                  child: const Text('LAUNCH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Reading Telemetry & Streak Card (Positioned directly below Profile / Retrocognition)
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
                      Text(
                        'READING TELEMETRY & STREAKS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: EpilogueTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.storageService.isStreakBroken()) ...[
                            FilledButton.icon(
                              onPressed: () => _restoreStreak(state),
                              icon: const Icon(Icons.restore, size: 13, color: Colors.black),
                              label: const Text('RESTORE (🪙 10K)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
                              style: FilledButton.styleFrom(
                                backgroundColor: EpilogueTheme.starGold,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          TextButton.icon(
                            onPressed: _openManualImportDialog,
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('MANUAL IMPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Reading Streak', style: TextStyle(fontSize: 13, color: EpilogueTheme.textSecondary)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$currentStreak Days 🔥',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: currentStreak > 0 ? EpilogueTheme.starGold : EpilogueTheme.textPrimary,
                            ),
                          ),
                          if (widget.storageService.isStreakBroken()) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _restoreStreak(state),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EpilogueTheme.dangerAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: EpilogueTheme.dangerAccent.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'BROKEN (RESTORE)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: EpilogueTheme.dangerAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Longest Streak Record', '$longestStreak Days'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Read Today', '${todayStats.totalWords} Words (${(todayStats.totalSeconds / 60).toStringAsFixed(0)} mins)'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Total Reading Time', '$hours Hours'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Total Words Consumed', '$wordsFormatted Words'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Total Pages Read', '$totalPages Pages'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Average Reading Velocity', '$wpm WPM'),
                  Divider(color: EpilogueTheme.border, height: 18),
                  _statRow('Completed Volumes', '$completedBooks Completed'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Constellation Modifier Collapsible Card
          _buildCollapsibleOwnedSection(
            title: 'CONSTELLATION MODIFIERS',
            count: state.unlockedModifiers.length,
            activeItem: state.constellationModifier,
            activeLabel: 'Active',
            activeColor: EpilogueTheme.cyanAccent,
            isCollapsed: _modifiersCollapsed,
            onToggleCollapse: () => setState(() => _modifiersCollapsed = !_modifiersCollapsed),
            onOpenStore: () => _showModifierSelectorSheet(state),
            searchController: _modifiersSearchCtrl,
            searchQuery: _modifiersSearch,
            onSearchChanged: (q) => setState(() => _modifiersSearch = q),
            items: state.unlockedModifiers,
            isSelected: (m) => m == state.constellationModifier,
            onSelect: (m) => _orvService.equipModifier(m),
            chipIcon: Icons.star_border,
            emptyMessage: 'No Constellation Modifiers unlocked yet. You are an unaligned Incarnation.',
            searchHint: 'Search unlocked modifiers...',
          ),
          const SizedBox(height: 14),

          // Incarnation Attributes Collapsible Card
          _buildCollapsibleOwnedSection(
            title: 'INCARNATION ATTRIBUTES',
            count: state.unlockedAttributes.length,
            activeItem: state.equippedAttribute,
            activeLabel: 'Active',
            activeColor: EpilogueTheme.cyanAccent,
            isCollapsed: _attributesCollapsed,
            onToggleCollapse: () => setState(() => _attributesCollapsed = !_attributesCollapsed),
            onOpenStore: () => _showAttributesManagerSheet(state),
            searchController: _attributesSearchCtrl,
            searchQuery: _attributesSearch,
            onSearchChanged: (q) => setState(() => _attributesSearch = q),
            items: state.unlockedAttributes,
            isSelected: (a) => a == state.equippedAttribute,
            onSelect: (a) => _orvService.equipAttribute(a),
            chipIcon: null,
            emptyMessage: 'No Attributes unlocked yet. Unlock attributes from the store or clear high-rank Scenarios.',
            searchHint: 'Search unlocked attributes...',
          ),
          const SizedBox(height: 14),

          // Acquired Fables Collapsible Card
          _buildCollapsibleOwnedSection(
            title: 'ACQUIRED FABLES & STORIES',
            count: state.acquiredFables.length,
            activeItem: state.equippedFable,
            activeLabel: 'Active Fable',
            activeColor: EpilogueTheme.starGold,
            isCollapsed: _fablesCollapsed,
            onToggleCollapse: () => setState(() => _fablesCollapsed = !_fablesCollapsed),
            onOpenStore: () => _showFablesManagerSheet(state),
            searchController: _fablesSearchCtrl,
            searchQuery: _fablesSearch,
            onSearchChanged: (q) => setState(() => _fablesSearch = q),
            items: state.acquiredFables,
            isSelected: (f) => f == state.equippedFable,
            onSelect: (f) => _orvService.equipFable(f),
            chipIcon: Icons.auto_awesome,
            emptyMessage: 'No Fables acquired yet. Clear Scenarios in the Scenarios tab to begin forging your story.',
            searchHint: 'Search acquired fables...',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCollapsibleOwnedSection({
    required String title,
    required int count,
    required String activeItem,
    required String activeLabel,
    required Color activeColor,
    required bool isCollapsed,
    required VoidCallback onToggleCollapse,
    required VoidCallback onOpenStore,
    required TextEditingController searchController,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
    required List<String> items,
    required bool Function(String) isSelected,
    required Future<void> Function(String) onSelect,
    required IconData? chipIcon,
    required String emptyMessage,
    required String searchHint,
  }) {
    final filtered = items.where((i) => i.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Card(
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
                InkWell(
                  onTap: onToggleCollapse,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Text(
                        '$title ($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: EpilogueTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        size: 18,
                        color: EpilogueTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenStore,
                  icon: const Icon(Icons.storefront, size: 14),
                  label: const Text('ALL & STORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$activeLabel: [ ${activeItem.isNotEmpty ? activeItem : 'None'} ]',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: activeItem.isNotEmpty ? activeColor : EpilogueTheme.textMuted,
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(
                  emptyMessage,
                  style: TextStyle(fontSize: 12, color: EpilogueTheme.textSecondary),
                )
              else ...[
                // Search Bar
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: TextStyle(fontSize: 12, color: EpilogueTheme.textMuted),
                      prefixIcon: Icon(Icons.search, size: 16, color: EpilogueTheme.textSecondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: EpilogueTheme.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: EpilogueTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: EpilogueTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: EpilogueTheme.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No matching items found.',
                      style: TextStyle(fontSize: 12, color: EpilogueTheme.textMuted, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in filtered)
                        FilterChip(
                          avatar: chipIcon != null
                              ? Icon(
                                  chipIcon,
                                  size: 14,
                                  color: isSelected(item) ? activeColor : EpilogueTheme.textSecondary,
                                )
                              : null,
                          label: Text(item),
                          selected: isSelected(item),
                          onSelected: (_) async {
                            await onSelect(item);
                            if (mounted) setState(() {});
                          },
                          backgroundColor: EpilogueTheme.surfaceElevated,
                          selectedColor: activeColor.withValues(alpha: 0.15),
                          side: BorderSide(
                            color: isSelected(item) ? activeColor : EpilogueTheme.border,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected(item) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected(item) ? activeColor : EpilogueTheme.textPrimary,
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: EpilogueTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EpilogueTheme.textPrimary),
        ),
      ],
    );
  }
}
