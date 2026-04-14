
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGeneratorResponse {
  final Uint8List bytes;
  final int pageCount;
  PdfGeneratorResponse(this.bytes, this.pageCount);
}

class PdfGeneratorService {
  static Future<PdfGeneratorResponse> generateFromJson(Map<String, dynamic> rawData) async {
    final pdf = pw.Document();
    
    // Check if data is wrapped in a 'data' field
    Map<String, dynamic> data = rawData;
    if (rawData.containsKey('data') && rawData['data'] is Map<String, dynamic> && !rawData.containsKey('items')) {
      data = rawData['data'];
    }

    // Attempt to get items using various common keys
    List<dynamic> items = data['items'] ?? data['rows'] ?? data['products'] ?? data['list'] ?? data['data'] ?? data['details'] ?? data['positions'] ?? data['items_list'] ?? [];
    
    // If items is still empty, search for ANY list in the map
    if (items.isEmpty) {
      for (var value in data.values) {
        if (value is List && value.isNotEmpty) {
          items = value;
          break;
        }
      }
    }

    final String title = data['title'] ?? data['store_name'] ?? data['name'] ?? data['header'] ?? data['caption'] ?? 'Ro\'yxat';
    final String address = data['address'] ?? data['location'] ?? data['branch'] ?? '';
    final String date = data['date'] ?? data['created_at'] ?? data['datetime'] ?? data['sana'] ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final String total = data['total']?.toString() ?? data['total_sum']?.toString() ?? data['grand_total']?.toString() ?? data['all_total']?.toString() ?? data['jami']?.toString() ?? '0';
    final String currency = data['currency'] ?? data['unit'] ?? data['valyuta'] ?? "";
    final String footer = data['footer'] ?? data['note'] ?? data['remark'] ?? data['izoh'] ?? "Ro'yxat yakunlandi";
    
    // Dynamic columns support
    final List<dynamic> headers = data['headers'] ?? [
      data['header_name'] ?? 'Nomi',
      data['header_qty'] ?? 'Soni',
      data['header_total'] ?? 'Jami'
    ];
    
    // If keys not provided, try to detect them from the first item
    List<dynamic> keys = data['keys'] ?? [];
    if (keys.isEmpty && items.isNotEmpty && items.first is Map) {
      final Map firstItem = items.first;
      // Common patterns: name/title/label, qty/count/amount, total/price/sum
      String nameKey = ['name', 'title', 'label', 'product_name'].firstWhere((k) => firstItem.containsKey(k), orElse: () => firstItem.keys.first.toString());
      String qtyKey = ['qty', 'count', 'quantity', 'amount', 'soni'].firstWhere((k) => firstItem.containsKey(k), orElse: () => firstItem.keys.length > 1 ? firstItem.keys.elementAt(1).toString() : 'qty');
      String totalKey = ['total', 'price', 'sum', 'total_price', 'jami'].firstWhere((k) => firstItem.containsKey(k), orElse: () => firstItem.keys.length > 2 ? firstItem.keys.elementAt(2).toString() : 'total');
      keys = [nameKey, qtyKey, totalKey];
    } else if (keys.isEmpty) {
      keys = ['name', 'qty', 'total'];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            'Bet ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                      if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("Sana: $date", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.Placeholder(), // Optional space for logo
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Table Header with Border
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: headers.asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final String h = entry.value.toString();
                  return pw.Expanded(
                    flex: idx == 0 ? 3 : 1,
                    child: pw.Text(
                      h.toUpperCase(), 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      textAlign: idx == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                    ),
                  );
                }).toList(),
              ),
            ),
            // Items with light borders
            ...items.map((item) {
              return pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300)),
                ),
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Row(
                  children: keys.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final String k = entry.value.toString();
                    final String val = item[k]?.toString() ?? '';
                    return pw.Expanded(
                      flex: idx == 0 ? 3 : 1,
                      child: pw.Text(
                        val, 
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: idx == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
            pw.SizedBox(height: 20),
            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("JAMI: $total $currency", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 4),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
              ],
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 50),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 150, 
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide())
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text("Mas'ul shaxs imzosi", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("M.O'.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text("(Muhr uchun joy)", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            footer,
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    final Uint8List bytes = await pdf.save();
    final int pageCount = pdf.document.pdfPageList.pages.length;
    return PdfGeneratorResponse(bytes, pageCount);
  }
}
