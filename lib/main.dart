
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/gen_l10n/app_localizations.dart';
import 'providers/app_provider.dart';
import 'ui/home_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Window Manager
  await windowManager.ensureInitialized();
  
  // Single Instance Check
  try {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 18765);
    // Keep reference to prevent GC, though in main it's likely fine
  } catch (e) {
    // Port already in use, so another instance is running
    exit(0);
  }

  // Initialize Package Info
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  
  // Initialize Launch at Startup
  launchAtStartup.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
    packageName: 'com.example.autoprint',
  );

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'AutoPrint Agent',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Register Window Listener
    windowManager.addListener(_WindowListener());
    await windowManager.setPreventClose(true);

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
    final provider = context.watch<AppProvider>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AutoPrint Agent',
      debugShowCheckedModeBanner: false,
      locale: Locale(provider.settings.locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uz'),
        Locale('ru'),
        Locale('en'),
      ],
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

class _WindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
}
