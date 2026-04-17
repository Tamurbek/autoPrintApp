
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/settings.dart';
import 'pdf_generator_service.dart';
import '../models/print_job.dart';


class PrintService {
  Timer? _timer;
  Timer? _pingTimer;
  bool _isPolling = false;
  bool _isPingInProgress = false;
  bool _isJobCheckInProgress = false;

  void startPolling(AppSettings settings, Function(String) onLog, Function(Uint8List, int?, String jobUuid, int copies, PrintJob job) onPrint, {Function(Map<String, dynamic>?)? onPingSuccess}) {
    _timer?.cancel();
    _pingTimer?.cancel();
    _isPolling = true;

    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_isPingInProgress) return;
      _isPingInProgress = true;
      try {
        final res = await sendPing(settings, onLog, onSuccess: () {});
        if (res != null) onPingSuccess?.call(res);
      } finally {
        _isPingInProgress = false;
      }
    });

    // Send initial ping immediately
    sendPing(settings, onLog, onSuccess: () {}).then((res) {
      if (res != null) onPingSuccess?.call(res);
    });

    // Jobs Polling Timer
    _timer = Timer.periodic(Duration(seconds: settings.pollingInterval), (timer) async {
      if (_isJobCheckInProgress) return;
      _isJobCheckInProgress = true;
      try {
        await checkPendingJobs(settings, onLog, onPrint);
      } finally {
        _isJobCheckInProgress = false;
      }
    });
    
    // Check once immediately on start
    _isJobCheckInProgress = true;
    checkPendingJobs(settings, onLog, onPrint).then((_) => _isJobCheckInProgress = false);
  }

  Future<void> checkPendingJobs(AppSettings settings, Function(String) onLog, Function(Uint8List, int?, String jobUuid, int copies, PrintJob job) onPrint) async {
    if (!_isPolling || settings.apiKey.isEmpty) return;
    
    try {
      final response = await http.get(
        Uri.parse("${settings.apiUrl}/api/external/printers/jobs/pending"),
        headers: {
          'X-API-KEY': settings.apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        String logBody = response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body;
        onLog("Server javobi (jobs): $logBody");
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List jobsData = body['data'];
          if (jobsData.isNotEmpty) {
            onLog("${jobsData.length} ta yangi topshiriq topildi.");
            
            for (var jobData in jobsData) {
              final job = PrintJob.fromJson(jobData);
              onLog("Topshiriq yuklanmoqda: ${job.documentName} (${job.copies} nusxa)");
              
              try {
                Uint8List? printData;
                int? pageCount;

                if (job.type == 'html') {
                  if (Platform.isWindows || Platform.isLinux) {
                    throw Exception("Windows/Linux tizimlarida HTML-dan chop etish qo'llab-quvvatlanmaydi. Iltimos, serverda 'json' yoki 'pdf' turidan foydalaning.");
                  }
                  printData = await Printing.convertHtml(
                    html: job.html ?? '',
                    format: PdfPageFormat.a4,
                  );
                } else if (job.type == 'json') {
                  final dynamic decoded = jsonDecode(job.html ?? '{}');
                  Map<String, dynamic> jsonData;
                  if (decoded is List) {
                    jsonData = {'items': decoded};
                  } else {
                    jsonData = decoded as Map<String, dynamic>;
                  }
                  final genResponse = await PdfGeneratorService.generateFromJson(jsonData);
                  printData = genResponse.bytes;
                  pageCount = genResponse.pageCount;
                } else if (job.type == 'pdf') {
                  final base64String = job.base64Data ?? job.html ?? '';
                  if (base64String.isNotEmpty) {
                    printData = base64Decode(base64String);
                  } else {
                    throw Exception("PDF ma'lumotlari topilmadi.");
                  }
                }

                if (printData != null) {
                  onPrint(printData, pageCount, job.uuid, job.copies, job);
                } else {
                  await reportStatus(settings, job.uuid, 'failed', error: "Unsupported job type: ${job.type}");
                }
              } catch (e) {
                onLog("Chop etishga tayyorlashda xatolik: $e");
                await reportStatus(settings, job.uuid, 'failed', error: e.toString());
              }
            }
          }
        }
      } else if (response.statusCode != 204) {
        String logBody = response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body;
        onLog("API Error: ${response.statusCode} - $logBody");
      }
    } catch (e) {
      onLog("Error fetching jobs: $e");
    }
  }


  Future<void> reportStatus(AppSettings settings, String jobUuid, String status, {String? error}) async {
    try {
      await http.post(
        Uri.parse("${settings.apiUrl}/api/external/printers/jobs/$jobUuid/status"),
        headers: {
          'X-API-KEY': settings.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status,
          'error': error,
        }),
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      print("Status reporting error: $e");
    }
  }

  Future<Map<String, dynamic>?> sendPing(AppSettings settings, Function(String) onLog, {VoidCallback? onSuccess}) async {
    if (settings.apiKey.isEmpty) return null;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http.post(
        Uri.parse("${settings.apiUrl}/api/external/printers/ping"),
        headers: {
          'X-API-KEY': settings.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': packageInfo.version,
          'hostname': Platform.localHostname,
          'os': Platform.operatingSystem,
          'printer_name': settings.selectedPrinter ?? 'Not Selected',
          'status': 'running',
          'last_ping': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 301 || response.statusCode == 308) {
        final newLocation = response.headers['location'];
        if (newLocation != null) {
          onLog("Server URL manzili o'zgargan (Redirect): $newLocation");
          return {'redirect': newLocation};
        }
      }

      if (response.statusCode == 200) {
        String logBody = response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body;
        onLog("Server javobi (ping): $logBody");
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          onSuccess?.call();
          if (body['printer_name'] != null) {
             // onLog("Server recognized printer: ${body['printer_name']}");
          }
          return body;
        } else {
          onLog("Ping Server Error: ${body['message'] ?? 'Unknown server error'}");
        }
      } else {
        String logBody = response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body;
        onLog("Ping HTTP Error: ${response.statusCode} - $logBody");
      }
    } catch (e) {
      onLog("Ping Exception: $e");
    }
    return null;
  }


  void stopPolling() {
    _isPolling = false;
    _timer?.cancel();
    _pingTimer?.cancel();
  }

  Future<void> printDocument(Uint8List data, String? printerName, {int copies = 1}) async {
    if (printerName == null) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => data);
      return;
    }

    final printers = await Printing.listPrinters();
    final printer = printers.firstWhere(
      (p) => p.name == printerName,
      orElse: () => printers.first,
    );

    for (int i = 0; i < copies; i++) {
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (PdfPageFormat format) async => data,
      );
    }
  }

  
  Future<List<Printer>> getPrinters() async {
    return await Printing.listPrinters();
  }
}

