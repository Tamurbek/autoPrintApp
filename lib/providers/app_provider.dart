
import 'dart:io';
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
import '../services/websocket_service.dart';
import '../models/print_job.dart';

class AppProvider extends ChangeNotifier with TrayListener {

  AppSettings _settings = AppSettings(
    apiUrl: "http://10.42.0.255", 
    apiKey: "cd8d7cd62ea64c5aa5cac6b48ed12e3f",
  );

  final PrintService _printService = PrintService();
  final UpdateService _updateService = UpdateService();
  late final WebSocketService _wsService;
  final List<String> _logs = [];
  List<Printer> _availablePrinters = [];
  
  Map<String, dynamic>? _updateData;
  double _downloadProgress = 0;
  bool _isDownloading = false;
  bool _isWsConnected = false;
  DateTime? _lastPingTime;
  Uint8List? _lastPdfBytes;
  final List<PrintJob> _pendingQueue = [];

  AppSettings get settings => _settings;
  List<String> get logs => _logs;
  List<Printer> get availablePrinters => _availablePrinters;
  Map<String, dynamic>? get updateData => _updateData;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  bool get isWsConnected => _isWsConnected;
  bool get isPingActive {
    if (_lastPingTime == null) return false;
    return DateTime.now().difference(_lastPingTime!).inSeconds < 40; // Allow some buffer
  }
  Uint8List? get lastPdfBytes => _lastPdfBytes;
  List<PrintJob> get pendingQueue => _pendingQueue;

  AppProvider() {
    _initWsService();
    _loadSettings();
    _refreshPrinters();
    _initTray();
  }

  void _initWsService() {
    // Polling callback
    final onLogCb = (String msg) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: $msg");
      if (_logs.length > 100) _logs.removeLast();
      notifyListeners();
    };

    final onPrintCb = (Uint8List data, int? pageCount, String jobUuid, int copies) async {
      _lastPdfBytes = data;
      notifyListeners();
      
      final context = navigatorKey.currentContext;
      if (context != null) {
        bool confirmed = true;
        if (!_settings.autoPrintEnabled) {
          confirmed = await PrintConfirmationDialog.show(context, pageCount) ?? false;
        }

        if (confirmed) {
          try {
            await _printService.printDocument(data, _settings.selectedPrinter, copies: copies);
            onLogCb("Hujjat chop etildi ($copies nusxa).");
            await _printService.reportStatus(_settings, jobUuid, 'completed');
          } catch (e) {
            onLogCb("Xatolik: $e");
            await _printService.reportStatus(_settings, jobUuid, 'failed', error: e.toString());
          }
        } else {
          onLogCb("Chop etish bekor qilindi.");
        }
        notifyListeners();
      }
    };

    _wsService = WebSocketService(
      onLog: onLogCb,
      onNewJob: () {
        onLogCb("WebSocket: Yangi topshiriq xabari olindi.");
        // Filter out jobs already in the queue
        _printService.checkPendingJobs(_settings, onLogCb, (data, count, uuid, copies, job) {
           _processJob(data, count, uuid, copies, job);
        });
      },
      onStatusChange: (status) {
        _isWsConnected = status;
        notifyListeners();
      },
    );
  }

  Future<void> _initTray() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        if (Platform.isWindows) {
          await trayManager.setIcon('assets/app_icon.ico');
        } else {
          await trayManager.setIcon('assets/icon.png');
        }

        
        // Since we don't have context here yet for localization, we use default strings
        // or we could refactor to set it later. 
        // Let's use more generic names or set them once settings are loaded.
        
        Menu menu = Menu(
          items: [
            MenuItem(label: 'Ochish', onClick: (_) => windowManager.show()),
            MenuItem.separator(),
            MenuItem(label: 'Chiqish', onClick: (_) => exit(0)),
          ],
        );

        await trayManager.setContextMenu(menu);
        trayManager.addListener(this);
      } catch (e) {
        debugPrint('Tray initialization error: $e');
      }
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String apiUrl = prefs.getString('apiUrl') ?? "http://10.42.0.255";
    _settings = AppSettings(
      apiUrl: _normalizeUrl(apiUrl),
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
    // Check jobs regardless, they will go to queue if autoPrint is off
    _checkForJobsInitially();
    checkForUpdates();
  }

  void _checkForJobsInitially() {
    _printService.checkPendingJobs(_settings, (msg) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: $msg");
      notifyListeners();
    }, _processJob);
  }

  void _processJob(Uint8List data, int? pageCount, String jobUuid, int copies, PrintJob job) async {
    _lastPdfBytes = data;
    // Check if duplicate
    if (_pendingQueue.any((j) => j.uuid == jobUuid)) return;

    if (_settings.autoPrintEnabled && _settings.selectedPrinter != null) {
      try {
        await _printService.printDocument(data, _settings.selectedPrinter, copies: copies);
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Hujjat avtomatik chop etildi.");
        await _printService.reportStatus(_settings, jobUuid, 'completed');
        notifyListeners();
      } catch (e) {
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Xatolik: $e");
        await _printService.reportStatus(_settings, jobUuid, 'failed', error: e.toString());
        notifyListeners();
      }
    } else {
      // Add to manual queue
      job.pdfBytes = data; // We'll need to store bytes in the job model temporarily
      _pendingQueue.add(job);
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Yangi vazifa navbatga qo'shildi: ${job.documentName}");
      notifyListeners();
    }
  }

  Future<void> printQueueItem(PrintJob job) async {
    if (job.pdfBytes == null) return;
    try {
      await _printService.printDocument(job.pdfBytes!, _settings.selectedPrinter, copies: job.copies);
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Hujjat chop etildi: ${job.documentName}");
      await _printService.reportStatus(_settings, job.uuid, 'completed');
      _pendingQueue.removeWhere((j) => j.uuid == job.uuid);
      notifyListeners();
    } catch (e) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Xatolik: $e");
    }
  }

  Future<void> cancelQueueItem(PrintJob job) async {
    try {
      await _printService.reportStatus(_settings, job.uuid, 'failed', error: "Foydalanuvchi bekor qildi");
      _pendingQueue.removeWhere((j) => j.uuid == job.uuid);
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Vazifa bekor qilindi: ${job.documentName}");
      notifyListeners();
    } catch (e) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Bekor qilishda xato: $e");
    }
  }

  Future<void> checkForUpdates() async {
    final update = await _updateService.checkUpdate();
    if (update != null) {
      _updateData = update;
      notifyListeners();
    } else {
      _updateData = null;
      notifyListeners();
    }
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
    final normalizedApiUrl = apiUrl != null ? _normalizeUrl(apiUrl) : null;

    _settings = _settings.copyWith(
      apiUrl: normalizedApiUrl,
      apiKey: apiKey,
      selectedPrinter: selectedPrinter,
      autoPrintEnabled: autoPrintEnabled,
      startAtBoot: startAtBoot,
      locale: locale,
      pollingInterval: pollingInterval,
    );

    final prefs = await SharedPreferences.getInstance();
    if (normalizedApiUrl != null) await prefs.setString('apiUrl', normalizedApiUrl);
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
      _stopService();
    }

    
    notifyListeners();
  }

  void _startService() {
    // Polling parameters
    final onLogCb = (String msg) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: $msg");
      if (_logs.length > 100) _logs.removeLast();
      notifyListeners();
    };

    _printService.startPolling(_settings, onLogCb, _processJob, onPingSuccess: (result) async {
      _lastPingTime = DateTime.now();
      
      if (result != null && result['redirect'] != null) {
        final newUrl = result['redirect'] as String;
        final uri = Uri.parse(newUrl);
        final baseUrl = "${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ":${uri.port}" : ""}";
        
        await updateSettings(apiUrl: baseUrl);
        onLogCb("Tizim avtomatik ravishda yangi server manziliga moslashdi: $baseUrl");
      }
      
      notifyListeners();
    });
    _wsService.connect(_settings);
    // Periodically send ping in a separate timer or just rely on startPolling's ping
    // startPolling already has a timer, we just need to pass the onSuccess callback.
    // Let's modify startPolling to accept it.
  }

  void _stopService() {
    _printService.stopPolling();
    _wsService.disconnect();
  }



  Future<void> manualPing() async {
    _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Qo'lda ping yuborilmoqda...");
    notifyListeners();
    try {
      final result = await _printService.sendPing(_settings, (msg) {
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Ping: $msg");
        notifyListeners();
      }, onSuccess: () {
        _lastPingTime = DateTime.now();
        notifyListeners();
      });

      if (result != null && result['redirect'] != null) {
        final newUrl = result['redirect'] as String;
        // Strip out the relative path to get the base URL
        final uri = Uri.parse(newUrl);
        final baseUrl = "${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ":${uri.port}" : ""}";
        
        await updateSettings(apiUrl: baseUrl);
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Tizim avtomatik ravishda yangi server manziliga moslashdi: $baseUrl");
      }
      
      if (result != null && result['success'] == true) {
        _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Ping muvaffaqiyatli yuborildi.");
      }
    } catch (e) {
      _logs.insert(0, "${DateTime.now().toString().split('.')[0]}: Ping yuborishda xatolik: $e");
    }
    notifyListeners();
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

  String _normalizeUrl(String url) {
    url = url.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    final apiIndex = url.indexOf('/api/external');
    if (apiIndex != -1) {
      url = url.substring(0, apiIndex);
    }
    return url;
  }
}
