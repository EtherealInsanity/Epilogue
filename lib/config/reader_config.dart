import 'dart:convert';

enum AppNavigationStyle {
  bottomBar,
  floatingDock,
}

enum PageAnimationType {
  smoothSlide,
  instantSnap,
  continuousScroll,
}

enum ReaderThemePreset {
  paperLight,
  sepiaWarm,
  slateGray,
  oledDark,
}

class ReaderConfig {
  final ReaderThemePreset themePreset;
  final AppNavigationStyle navigationStyle;
  final PageAnimationType pageAnimation;
  final double fontSize;
  final double lineSpacing;
  final String fontFamily; // 'sans', 'serif', 'mono'
  final String textAlignment; // 'justify', 'left'
  final bool keepScreenAwake;
  final bool fullscreenReader;
  final bool volumeKeysPaging;
  final bool hapticFeedback;
  final String? libraryFolderPath;

  // New features: UI Scaling, Margins, Auto-scroll & Rich CSS
  final double uiScale; // 0.85 to 1.35
  final double horizontalMargin; // 12.0, 20.0, 32.0
  final double autoScrollSpeed; // 0.0 (off) to 80.0 px/s
  final bool showReadingHeaderFooter;
  final bool customCssEnabled;
  final bool useOriginalBookStyles;
  final bool fourthWallActive;
  final String fourthWallHexColor;
  final bool enableEpubStudio;

  const ReaderConfig({
    this.themePreset = ReaderThemePreset.paperLight,
    this.navigationStyle = AppNavigationStyle.bottomBar,
    this.pageAnimation = PageAnimationType.smoothSlide,
    this.fontSize = 17.0,
    this.lineSpacing = 1.6,
    this.fontFamily = 'serif',
    this.textAlignment = 'left',
    this.keepScreenAwake = true,
    this.fullscreenReader = false,
    this.volumeKeysPaging = true,
    this.hapticFeedback = true,
    this.libraryFolderPath,
    this.uiScale = 1.0,
    this.horizontalMargin = 20.0,
    this.autoScrollSpeed = 0.0,
    this.showReadingHeaderFooter = true,
    this.customCssEnabled = true,
    this.useOriginalBookStyles = false,
    this.fourthWallActive = false,
    this.fourthWallHexColor = '#0A192F',
    this.enableEpubStudio = false,
  });

  ReaderConfig copyWith({
    ReaderThemePreset? themePreset,
    AppNavigationStyle? navigationStyle,
    PageAnimationType? pageAnimation,
    double? fontSize,
    double? lineSpacing,
    String? fontFamily,
    String? textAlignment,
    bool? keepScreenAwake,
    bool? fullscreenReader,
    bool? volumeKeysPaging,
    bool? hapticFeedback,
    String? libraryFolderPath,
    double? uiScale,
    double? horizontalMargin,
    double? autoScrollSpeed,
    bool? showReadingHeaderFooter,
    bool? customCssEnabled,
    bool? useOriginalBookStyles,
    bool? fourthWallActive,
    String? fourthWallHexColor,
    bool? enableEpubStudio,
  }) {
    return ReaderConfig(
      themePreset: themePreset ?? this.themePreset,
      navigationStyle: navigationStyle ?? this.navigationStyle,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlignment: textAlignment ?? this.textAlignment,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      fullscreenReader: fullscreenReader ?? this.fullscreenReader,
      volumeKeysPaging: volumeKeysPaging ?? this.volumeKeysPaging,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      libraryFolderPath: libraryFolderPath ?? this.libraryFolderPath,
      uiScale: uiScale ?? this.uiScale,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      showReadingHeaderFooter: showReadingHeaderFooter ?? this.showReadingHeaderFooter,
      customCssEnabled: customCssEnabled ?? this.customCssEnabled,
      useOriginalBookStyles: useOriginalBookStyles ?? this.useOriginalBookStyles,
      fourthWallActive: fourthWallActive ?? this.fourthWallActive,
      fourthWallHexColor: fourthWallHexColor ?? this.fourthWallHexColor,
      enableEpubStudio: enableEpubStudio ?? this.enableEpubStudio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themePreset': themePreset.name,
      'navigationStyle': navigationStyle.name,
      'pageAnimation': pageAnimation.name,
      'fontSize': fontSize,
      'lineSpacing': lineSpacing,
      'fontFamily': fontFamily,
      'textAlignment': textAlignment,
      'keepScreenAwake': keepScreenAwake,
      'fullscreenReader': fullscreenReader,
      'volumeKeysPaging': volumeKeysPaging,
      'hapticFeedback': hapticFeedback,
      'libraryFolderPath': libraryFolderPath,
      'uiScale': uiScale,
      'horizontalMargin': horizontalMargin,
      'autoScrollSpeed': autoScrollSpeed,
      'showReadingHeaderFooter': showReadingHeaderFooter,
      'customCssEnabled': customCssEnabled,
      'useOriginalBookStyles': useOriginalBookStyles,
      'fourthWallActive': fourthWallActive,
      'fourthWallHexColor': fourthWallHexColor,
      'enableEpubStudio': enableEpubStudio,
    };
  }

  factory ReaderConfig.fromMap(Map<String, dynamic> map) {
    return ReaderConfig(
      themePreset: ReaderThemePreset.values.firstWhere(
        (e) => e.name == map['themePreset'],
        orElse: () => ReaderThemePreset.paperLight,
      ),
      navigationStyle: AppNavigationStyle.values.firstWhere(
        (e) => e.name == map['navigationStyle'],
        orElse: () => AppNavigationStyle.bottomBar,
      ),
      pageAnimation: PageAnimationType.values.firstWhere(
        (e) => e.name == map['pageAnimation'],
        orElse: () => PageAnimationType.smoothSlide,
      ),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 17.0,
      lineSpacing: (map['lineSpacing'] as num?)?.toDouble() ?? 1.6,
      fontFamily: map['fontFamily'] as String? ?? 'serif',
      textAlignment: map['textAlignment'] as String? ?? 'left',
      keepScreenAwake: map['keepScreenAwake'] as bool? ?? true,
      fullscreenReader: map['fullscreenReader'] as bool? ?? false,
      volumeKeysPaging: map['volumeKeysPaging'] as bool? ?? true,
      hapticFeedback: map['hapticFeedback'] as bool? ?? true,
      libraryFolderPath: map['libraryFolderPath'] as String?,
      uiScale: (map['uiScale'] as num?)?.toDouble() ?? 1.0,
      horizontalMargin: (map['horizontalMargin'] as num?)?.toDouble() ?? 20.0,
      autoScrollSpeed: (map['autoScrollSpeed'] as num?)?.toDouble() ?? 0.0,
      showReadingHeaderFooter: map['showReadingHeaderFooter'] as bool? ?? true,
      customCssEnabled: map['customCssEnabled'] as bool? ?? true,
      useOriginalBookStyles: map['useOriginalBookStyles'] as bool? ?? false,
      fourthWallActive: map['fourthWallActive'] as bool? ?? false,
      fourthWallHexColor: map['fourthWallHexColor'] as String? ?? '#0A192F',
      enableEpubStudio: map['enableEpubStudio'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ReaderConfig.fromJson(String source) =>
      ReaderConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
