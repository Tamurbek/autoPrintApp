
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../models/settings.dart';
import '../services/print_service.dart';
import '../services/update_service.dart';

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
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      apiUrl: prefs.getString('apiUrl') ?? "",
      selectedPrinter: prefs.getString('selectedPrinter'),
      autoPrintEnabled: prefs.getBool('autoPrintEnabled') ?? false,
      pollingInterval: prefs.getInt('pollingInterval') ?? 10,
    );
    notifyListeners();
    if (_settings.autoPrintEnabled) {
      _startService();
    }
    checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    _updateData = await _updateService.checkUpdate();
    notifyListeners();
  }

  Future<void> startUpdate() async {
    if (_updateData == null) return;
    _isDownloading = true;
    notifyListeners();

    await _updateService.downloadAndInstall(
      _updateData!['url'],
      (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
    );
  }

  Future<void> updateSettings({
    String? apiUrl,
    String? selectedPrinter,
    bool? autoPrintEnabled,
    int? pollingInterval,
  }) async {
    _settings = _settings.copyWith(
      apiUrl: apiUrl,
      selectedPrinter: selectedPrinter,
      autoPrintEnabled: autoPrintEnabled,
      pollingInterval: pollingInterval,
    );

    final prefs = await SharedPreferences.getInstance();
    if (apiUrl != null) await prefs.setString('apiUrl', apiUrl);
    if (selectedPrinter != null) await prefs.setString('selectedPrinter', selectedPrinter);
    if (autoPrintEnabled != null) await prefs.setBool('autoPrintEnabled', autoPrintEnabled);
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
}
