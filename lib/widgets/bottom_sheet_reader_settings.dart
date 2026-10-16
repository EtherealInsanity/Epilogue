import 'package:flutter/material.dart';
import '../config/reader_config.dart';
import '../services/storage_service.dart';
import '../theme/epilogue_theme.dart';

class BottomSheetReaderSettings extends StatefulWidget {
  final ReaderConfig config;
  final StorageService storageService;
  final int currentChapterIndex;
  final int totalChapters;
  final ValueChanged<ReaderConfig> onConfigChanged;
  final ValueChanged<int>? onChapterSeek;

  const BottomSheetReaderSettings({
    super.key,
    required this.config,
    required this.storageService,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.onConfigChanged,
    this.onChapterSeek,
  });

  @override
  State<BottomSheetReaderSettings> createState() => _BottomSheetReaderSettingsState();
}

class _BottomSheetReaderSettingsState extends State<BottomSheetReaderSettings> {
  late ReaderConfig _currentConfig;
  late double _scrubberValue;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.config;
    _scrubberValue = widget.currentChapterIndex.toDouble();
  }

  void _update(ReaderConfig next) {
    setState(() => _currentConfig = next);
    widget.storageService.saveConfig(next);
    widget.onConfigChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EpilogueTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: EpilogueTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reader Functions & Typography',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: EpilogueTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: EpilogueTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: EpilogueTheme.border),

              // 1. Reading Mode: Continuous Scroll vs Page Flip
              const SizedBox(height: 6),
              const Text(
                'READING MODE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: EpilogueTheme.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.unfold_more, size: 18),
                      label: const Text('Vertical Scroll'),
                      onPressed: () => _update(_currentConfig.copyWith(pageAnimation: PageAnimationType.continuousScroll)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentConfig.pageAnimation == PageAnimationType.continuousScroll
                            ? const Color(0xFFE0F2FE)
                            : EpilogueTheme.surface,
                        side: BorderSide(
                          color: _currentConfig.pageAnimation == PageAnimationType.continuousScroll
                              ? EpilogueTheme.cyanAccent
                              : EpilogueTheme.border,
                          width: _currentConfig.pageAnimation == PageAnimationType.continuousScroll ? 1.5 : 1.0,
                        ),
                        foregroundColor: _currentConfig.pageAnimation == PageAnimationType.continuousScroll
                            ? EpilogueTheme.cyanAccent
                            : EpilogueTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swipe, size: 18),
                      label: const Text('Page Turn'),
                      onPressed: () => _update(_currentConfig.copyWith(pageAnimation: PageAnimationType.smoothSlide)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentConfig.pageAnimation != PageAnimationType.continuousScroll
                            ? const Color(0xFFE0F2FE)
                            : EpilogueTheme.surface,
                        side: BorderSide(
                          color: _currentConfig.pageAnimation != PageAnimationType.continuousScroll
                              ? EpilogueTheme.cyanAccent
                              : EpilogueTheme.border,
                          width: _currentConfig.pageAnimation != PageAnimationType.continuousScroll ? 1.5 : 1.0,
                        ),
                        foregroundColor: _currentConfig.pageAnimation != PageAnimationType.continuousScroll
                            ? EpilogueTheme.cyanAccent
                            : EpilogueTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Chapter Scrubber (Jump Slider)
              if (widget.totalChapters > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CHAPTER SCRUBBER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: EpilogueTheme.textSecondary, letterSpacing: 0.5),
                    ),
                    Text(
                      'Ch. ${(_scrubberValue.round() + 1)} / ${widget.totalChapters}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent),
                    ),
                  ],
                ),
                Slider(
                  value: _scrubberValue.clamp(0.0, (widget.totalChapters - 1).toDouble()),
                  min: 0,
                  max: (widget.totalChapters - 1).toDouble(),
                  divisions: widget.totalChapters > 1 ? widget.totalChapters - 1 : 1,
                  activeColor: EpilogueTheme.accent,
                  onChanged: (val) => setState(() => _scrubberValue = val),
                  onChangeEnd: (val) {
                    if (widget.onChapterSeek != null) {
                      widget.onChapterSeek!(val.round());
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],

              // 3. Font Size Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Font Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: _currentConfig.fontSize > 12
                            ? () => _update(_currentConfig.copyWith(fontSize: _currentConfig.fontSize - 1))
                            : null,
                      ),
                      Text('${_currentConfig.fontSize.toStringAsFixed(0)} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: _currentConfig.fontSize < 34
                            ? () => _update(_currentConfig.copyWith(fontSize: _currentConfig.fontSize + 1))
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              Slider(
                value: _currentConfig.fontSize,
                min: 12,
                max: 34,
                divisions: 22,
                activeColor: EpilogueTheme.accent,
                onChanged: (val) => _update(_currentConfig.copyWith(fontSize: val)),
              ),

              // 4. Line Spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Line Spacing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                  Text('${_currentConfig.lineSpacing.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold, color: EpilogueTheme.cyanAccent)),
                ],
              ),
              Slider(
                value: _currentConfig.lineSpacing,
                min: 1.2,
                max: 2.4,
                divisions: 12,
                activeColor: EpilogueTheme.accent,
                onChanged: (val) => _update(_currentConfig.copyWith(lineSpacing: val)),
              ),

              // 5. Reading Margins
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Margins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
                  Row(
                    children: [
                      _marginOption(12.0, 'Compact'),
                      const SizedBox(width: 6),
                      _marginOption(20.0, 'Balanced'),
                      const SizedBox(width: 6),
                      _marginOption(32.0, 'Wide'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 6. Font Styles
              const Text('Font Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _fontOption('serif', 'Serif / Book'),
                  const SizedBox(width: 8),
                  _fontOption('sans', 'Sans / Modern'),
                  const SizedBox(width: 8),
                  _fontOption('mono', 'Mono / Code'),
                ],
              ),
              const SizedBox(height: 14),

              // 7. Background Theme Presets
              const Text('Color Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: EpilogueTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _themePresetTile(ReaderThemePreset.paperLight, 'Paper', const Color(0xFFF9FAFB), const Color(0xFF111827)),
                  const SizedBox(width: 8),
                  _themePresetTile(ReaderThemePreset.sepiaWarm, 'Warm', const Color(0xFFFBF0D9), const Color(0xFF2C2416)),
                  const SizedBox(width: 8),
                  _themePresetTile(ReaderThemePreset.slateGray, 'Slate', const Color(0xFFE2E8F0), const Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  _themePresetTile(ReaderThemePreset.oledDark, 'OLED', const Color(0xFF000000), const Color(0xFFE5E7EB)),
                ],
              ),
              const SizedBox(height: 14),

              // 8. Custom CSS & Constellation Message Highlighting Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _currentConfig.customCssEnabled,
                activeThumbColor: EpilogueTheme.cyanAccent,
                title: const Text('Constellation Message Styling', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Render Star Stream notifications with cyan glowing quotes', style: TextStyle(fontSize: 11)),
                onChanged: (val) => _update(_currentConfig.copyWith(customCssEnabled: val)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _currentConfig.useOriginalBookStyles,
                activeThumbColor: EpilogueTheme.cyanAccent,
                title: const Text('Original Book Formatting (EPUB CSS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Render headings, centered text, dividers, and styling classes from EPUB', style: TextStyle(fontSize: 11)),
                onChanged: (val) => _update(_currentConfig.copyWith(useOriginalBookStyles: val)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marginOption(double value, String label) {
    final isSelected = (_currentConfig.horizontalMargin - value).abs() < 1.0;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFFE0F2FE),
      backgroundColor: EpilogueTheme.surfaceElevated,
      side: BorderSide(color: isSelected ? EpilogueTheme.cyanAccent : EpilogueTheme.border),
      onSelected: (_) => _update(_currentConfig.copyWith(horizontalMargin: value)),
    );
  }

  Widget _fontOption(String id, String label) {
    final isSelected = _currentConfig.fontFamily == id;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _update(_currentConfig.copyWith(fontFamily: id)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: isSelected ? const Color(0xFFE0F2FE) : EpilogueTheme.surface,
          side: BorderSide(
            color: isSelected ? EpilogueTheme.cyanAccent : EpilogueTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? EpilogueTheme.cyanAccent : EpilogueTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _themePresetTile(ReaderThemePreset preset, String label, Color bg, Color text) {
    final isSelected = _currentConfig.themePreset == preset;
    return Expanded(
      child: InkWell(
        onTap: () => _update(_currentConfig.copyWith(themePreset: preset)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? EpilogueTheme.accent : EpilogueTheme.borderStrong,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text('Aa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: text.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}
