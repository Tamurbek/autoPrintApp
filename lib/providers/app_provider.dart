
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/settings.dart';
import '../services/print_service.dart';
import '../services/update_service.dart';
import '../ui/dialogs/app_update_dialog.dart';
import '../l10n/gen_l10n/app_localizations.dart';
import '../main.dart';

class AppProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings(apiUrl: "");
  final PrintService _printService = PrintService();
  final UpdateService _updateService = UpdateService();
  final List<String> _logs = [];
  List<Printer> _availablePrinters = [];
  
  Map<String, dynamic>? _updateData;
  double _downloadProgress = 0;
  bool _isDownloading = false;

  AppSettings get settings => _settings;
  List<String> get logs => _logs;
  List<Printer> get availablePrinters => _availablePrinters;
  Map<String, dynamic>? get updateData => _updateData;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  AppProvider() {
    _loadSettings();
    _refreshPrinters();
    _initTray();
  }

  Future<void> _initTray() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        await trayManager.setIcon(
          Platform.isWindows 
            ? 'windows/runner/resources/app_icon.ico' 
            : 'assets/icon.png',
        );
        Menu menu = Menu(
          items: [
            MenuItem(label: 'Open', onClick: (_) => windowManager.show()),
            MenuItem.separator(),
            MenuItem(label: 'Exit', onClick: (_) => exit(0)),
          ],
        );
        await trayManager.setContextMenu(menu);
      } catch (e) {
        debugPrint('Tray initialization error: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      apiUrl: prefs.getString('apiUrl') ?? "",
      selectedPrinter: prefs.getString('selectedPrinter'),
      autoPrintEnabled: prefs.getBool('autoPrintEnabled') ?? false,
      startAtBoot: prefs.getBool('startAtBoot') ?? true,
      locale: prefs.getString('locale') ?? 'uz',
      pollingInterval: prefs.getInt('pollingInterval') ?? 10,
    );
    notifyListeners();
    _updateAutoStart();
    if (_settings.autoPrintEnabled) {
      _startService();
    }
    checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    _updateData = await _updateService.checkUpdate();
    notifyListeners();
  }

  Future<void> manualCheckUpdate() async {
    final update = await _updateService.checkUpdate();
    if (update != null) {
      _updateData = update;
      notifyListeners();
      await startUpdate();
    } else {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noUpdate),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> startUpdate() async {
    if (_updateData != null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        AppUpdateDialog.show(
          context,
          _updateData!['version'],
          _updateData!['url'],
          changelog: _updateData!['changelog'],
        );
      }
    }
  }

  Future<void> updateSettings({
    String? apiUrl,
    String? selectedPrinter,
    bool? autoPrintEnabled,
    bool? startAtBoot,
    String? locale,
    int? pollingInterval,
  }) async {
    _settings = _settings.copyWith(
      apiUrl: apiUrl,
      selectedPrinter: selectedPrinter,
      autoPrintEnabled: autoPrintEnabled,
      startAtBoot: startAtBoot,
      locale: locale,
      pollingInterval: pollingInterval,
    );

    final prefs = await SharedPreferences.getInstance();
    if (apiUrl != null) await prefs.setString('apiUrl', apiUrl);
    if (selectedPrinter != null) await prefs.setString('selectedPrinter', selectedPrinter);
    if (autoPrintEnabled != null) await prefs.setBool('autoPrintEnabled', autoPrintEnabled);
    if (startAtBoot != null) {
      await prefs.setBool('startAtBoot', startAtBoot);
      _updateAutoStart();
    }
    if (locale != null) await prefs.setString('locale', locale);
    if (pollingInterval != null) await prefs.setInt('pollingInterval', pollingInterval);

    if (_settings.autoPrintEnabled) {
      _startService();
    } else {
      _printService.stopPolling();
    }
    
    notifyListeners();
  }

  void _startService() {
    _printService.startPolling(
      _settings,
      (msg) {
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: $msg");
        if (_logs.length > 100) _logs.removeLast();
        notifyListeners();
      },
      (data) {
        // Handle generic print success if needed
      },
    );
  }

  Future<void> _refreshPrinters() async {
    _availablePrinters = await _printService.getPrinters();
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> testPrint() async {
    if (_settings.selectedPrinter == null) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Error: Printer tanlanmagan");
      notifyListeners();
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text("AutoPrint Test Page", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text("Printer: ${_settings.selectedPrinter}"),
                  pw.Text("Date: ${DateTime.now()}"),
                  pw.SizedBox(height: 20),
                  pw.Text("Xizmat muvaffaqiyatli ishlamoqda!"),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final printer = _availablePrinters.firstWhere((p) => p.name == _settings.selectedPrinter);
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => bytes,
      );
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Test print yuborildi");
      notifyListeners();
    } catch (e) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Test print xatosi: $e");
      notifyListeners();
    }
  }

  Future<void> _updateAutoStart() async {
    if (Platform.isWindows) {
      if (_settings.startAtBoot) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    }
  }
}
