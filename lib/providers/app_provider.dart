
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/settings.dart';
import '../services/print_service.dart';
import '../services/update_service.dart';
import '../ui/dialogs/app_update_dialog.dart';
import '../ui/dialogs/print_confirmation_dialog.dart';
import '../l10n/gen_l10n/app_localizations.dart';
import '../main.dart';
import '../services/pdf_generator_service.dart';

class AppProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings(
    apiUrl: "http://10.42.0.255", 
    apiKey: "cd8d7cd62ea64c5aa5cac6b48ed12e3f",
  );

  final PrintService _printService = PrintService();
  final UpdateService _updateService = UpdateService();
  final List<String> _logs = [];
  List<Printer> _availablePrinters = [];
  
  Map<String, dynamic>? _updateData;
  double _downloadProgress = 0;
  bool _isDownloading = false;
  Uint8List? _lastPdfBytes;

  AppSettings get settings => _settings;
  List<String> get logs => _logs;
  List<Printer> get availablePrinters => _availablePrinters;
  Map<String, dynamic>? get updateData => _updateData;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  Uint8List? get lastPdfBytes => _lastPdfBytes;

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
      apiUrl: prefs.getString('apiUrl') ?? "http://10.42.0.255",
      apiKey: prefs.getString('apiKey') ?? "cd8d7cd62ea64c5aa5cac6b48ed12e3f",

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
    String? apiKey,
    String? selectedPrinter,
    bool? autoPrintEnabled,
    bool? startAtBoot,
    String? locale,
    int? pollingInterval,
  }) async {
    _settings = _settings.copyWith(
      apiUrl: apiUrl,
      apiKey: apiKey,
      selectedPrinter: selectedPrinter,
      autoPrintEnabled: autoPrintEnabled,
      startAtBoot: startAtBoot,
      locale: locale,
      pollingInterval: pollingInterval,
    );

    final prefs = await SharedPreferences.getInstance();
    if (apiUrl != null) await prefs.setString('apiUrl', apiUrl);
    if (apiKey != null) await prefs.setString('apiKey', apiKey);
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
      (data, pageCount, jobUuid) async {
        _lastPdfBytes = data;
        notifyListeners();
        
        final context = navigatorKey.currentContext;
        if (context != null) {
          bool confirmed = true;
          // If autoPrintEnabled is true, we might want to skip confirmation if settings allow
          // But here it seems the logic was to always show confirmation.
          // The user request says "har 5-10 soniyada jobs/pending endpointiga murojaat qiladi. Ro'yxatda ish paydo bo'lsa, uni chop etadi"
          // This implies automatic execution.
          
          if (_settings.autoPrintEnabled) {
            confirmed = true;
          } else {
            confirmed = await PrintConfirmationDialog.show(context, pageCount) ?? false;
          }

          if (confirmed) {
            try {
              await _printService.printDocument(data, _settings.selectedPrinter);
              _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Hujjat chop etildi.");
              await _printService.reportStatus(_settings, jobUuid, 'completed');
              notifyListeners();
            } catch (e) {
              _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Xatolik: $e");
              await _printService.reportStatus(_settings, jobUuid, 'failed', error: e.toString());
              notifyListeners();
            }
          } else {
            _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Chop etish bekor qilindi.");
            notifyListeners();
          }
        }
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
      _lastPdfBytes = bytes;
      notifyListeners();
      
      final context = navigatorKey.currentContext;
      if (context != null) {
        final confirmed = await PrintConfirmationDialog.show(context, 1);
        if (confirmed != true) return;
      }

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

  Future<void> testJsonPrint() async {
    if (_settings.selectedPrinter == null) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Error: Printer tanlanmagan");
      notifyListeners();
      return;
    }

    try {
      // Generate a long list of 130 students to fill approx 4 A4 pages
      final items = List.generate(130, (index) => {
        "name": "Talaba ${index + 1} Ism Sharif",
        "qty": "G-${(index % 10) + 100}",
        "total": index % 3 == 0 ? "Faol" : "Nofaol",
        "grade": "${(index % 4) + 2}"
      });

      final sampleJson = {
        "title": "Katta Talabalar Ro'yxati (4 Betlik)",
        "headers": ["F.I.SH.", "Guruh", "Status", "Baho"],
        "keys": ["name", "qty", "total", "grade"],
        "items": items,
        "total": items.length.toString(),
        "currency": "nafar talaba",
        "footer": "Barcha 4 betlik ma'lumotlar saqlandi."
      };

      final genResponse = await PdfGeneratorService.generateFromJson(sampleJson);
      final bytes = genResponse.bytes;
      _lastPdfBytes = bytes;
      notifyListeners();
      
      final context = navigatorKey.currentContext;
      if (context != null) {
        final confirmed = await PrintConfirmationDialog.show(context, genResponse.pageCount);
        if (confirmed != true) return;
      }

      final printer = _availablePrinters.firstWhere((p) => p.name == _settings.selectedPrinter);
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => bytes,
      );
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Test JSON print yuborildi");
      notifyListeners();
    } catch (e) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Test JSON print xatosi: $e");
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
