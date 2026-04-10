
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'providers/app_provider.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Window Manager
  await windowManager.ensureInitialized();
  
  // Initialize Package Info
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  
  // Initialize Launch at Startup
  launchAtStartup.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
    packageName: 'com.example.autoprint',
    registrationDirectory: 'Software\\SimpleSale\\AutoPrint',
  );

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'AutoPrint Agent',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Check if started with hidden flag (for autorun)
    if (Platform.environment.containsKey('START_HIDDEN') || 
        Platform.executableArguments.contains('--hidden')) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const AutoPrintApp(),
    ),
  );
}

class AutoPrintApp extends StatelessWidget {
  const AutoPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoPrint POS Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A), // Slate 900
          background: const Color(0xFF020617), // Slate 950
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B), // Slate 800
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
