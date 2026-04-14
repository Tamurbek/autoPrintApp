
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

  void startPolling(AppSettings settings, Function(String) onLog, Function(Uint8List, int?, String jobUuid, int copies, PrintJob job) onPrint, {VoidCallback? onPingSuccess}) {
    _timer?.cancel();
    _pingTimer?.cancel();
    _isPolling = true;

    _pingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      sendPing(settings, onLog, onSuccess: onPingSuccess);
    });

    // Send initial ping immediately
    sendPing(settings, onLog, onSuccess: onPingSuccess);

    // Jobs Polling Timer
    _timer = Timer.periodic(Duration(seconds: settings.pollingInterval), (timer) async {
      checkPendingJobs(settings, onLog, onPrint);
    });
    
    // Check once immediately on start
    checkPendingJobs(settings, onLog, onPrint);
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
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
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
                  printData = await Printing.convertHtml(
                    html: job.html,
                    format: PdfPageFormat.a4,
                  );
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
        onLog("API Error: ${response.statusCode} - ${response.body}");
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
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print("Status reporting error: $e");
    }
  }

  Future<void> sendPing(AppSettings settings, Function(String) onLog, {VoidCallback? onSuccess}) async {
    if (settings.apiKey.isEmpty) return;
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          onSuccess?.call();
          if (body['printer_name'] != null) {
             // onLog("Server recognized printer: ${body['printer_name']}");
          }
        } else {
          onLog("Ping Server Error: ${body['message'] ?? 'Unknown server error'}");
        }
      } else {
        onLog("Ping HTTP Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      onLog("Ping Exception: $e");
    }
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

