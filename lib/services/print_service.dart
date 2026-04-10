
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/settings.dart';
import 'pdf_generator_service.dart';

class PrintService {
  Timer? _timer;
  bool _isPolling = false;

  void startPolling(AppSettings settings, Function(String) onLog, Function(Uint8List, int?) onPrint) {
    _timer?.cancel();
    _isPolling = true;
    _timer = Timer.periodic(Duration(seconds: settings.pollingInterval), (timer) async {
      if (!_isPolling || !settings.autoPrintEnabled) return;
      
      try {
        onLog("Checking API: ${settings.apiUrl}");
        final response = await http.get(Uri.parse(settings.apiUrl));
        
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          Uint8List printData = response.bodyBytes;
          PdfGeneratorResponse? genResponse;
          
          // Check if response is JSON
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json') || response.body.trim().startsWith('{')) {
            try {
              onLog("JSON ma'lumot keldi, PDF-ga o'tkazilmoqda...");
              final jsonData = jsonDecode(response.body);
              genResponse = await PdfGeneratorService.generateFromJson(jsonData);
              printData = genResponse.bytes;
              onLog("Muvaffaqiyatli o'tkazildi: ${genResponse.pageCount} bet.");
            } catch (e) {
              onLog("JSON Parse Xatosi: $e. Xom ma'lumot sifatida chop etish...");
            }
          }

          onLog("Hujjat keldi. Tasdiqlash kutilmoqda...");
          // We can track pageCount if it's from JSON
          int? pageCount;
          if (genResponse != null) pageCount = genResponse.pageCount;
          
          onPrint(printData, pageCount); 
        } else if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
          // No documents to print
        } else {
          onLog("API Error: ${response.statusCode}");
        }
      } catch (e) {
        onLog("Error fetching/printing: $e");
      }
    });
  }

  void stopPolling() {
    _isPolling = false;
    _timer?.cancel();
  }

  Future<void> printDocument(Uint8List data, String? printerName) async {
    if (printerName == null) {
      // If no printer selected, show print dialog as fallback
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => data);
      return;
    }

    final printers = await Printing.listPrinters();
    final printer = printers.firstWhere(
      (p) => p.name == printerName,
      orElse: () => printers.first,
    );

    await Printing.directPrintPdf(
      printer: printer,
      onLayout: (PdfPageFormat format) async => data,
    );
  }
  
  Future<List<Printer>> getPrinters() async {
    return await Printing.listPrinters();
  }
}
