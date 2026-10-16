import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_shell_screen.dart';
import 'services/storage_service.dart';
import 'theme/epilogue_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crisp Paper/Frost Light System Bar Overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: EpilogueTheme.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final storageService = await StorageService.initialize();

  runApp(EpilogueApp(
    storageService: storageService,
  ));
}

class EpilogueApp extends StatelessWidget {
  final StorageService storageService;

  const EpilogueApp({
    super.key,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epilogue',
      debugShowCheckedModeBanner: false,
      theme: EpilogueTheme.lightTheme(),
      home: MainShellScreen(storageService: storageService),
    );
  }
}
