
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGeneratorService {
  static Future<Uint8List> generateFromJson(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    // Attempt to get items or fallback to empty list
    final List<dynamic> items = data['items'] ?? [];
    final String title = data['title'] ?? data['store_name'] ?? 'Ro\'yxat';
    final String address = data['address'] ?? '';
    final String date = data['date'] ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final String total = data['total']?.toString() ?? '0';
    final String currency = data['currency'] ?? "";
    final String footer = data['footer'] ?? "Ro'yxat yakunlandi";
    
    // Dynamic columns support
    final List<dynamic> headers = data['headers'] ?? [
      data['header_name'] ?? 'Nomi',
      data['header_qty'] ?? 'Soni',
      data['header_total'] ?? 'Jami'
    ];
    
    final List<dynamic> keys = data['keys'] ?? [
      'name',
      'qty',
      'total'
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30), // Increased margin for A4
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18), textAlign: pw.TextAlign.center),
                    if (address.isNotEmpty) pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(address, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // Header Row
              pw.Row(
                children: headers.asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final String h = entry.value.toString();
                  return pw.Expanded(
                    flex: idx == 0 ? 3 : 1, // First column (name) gets even more space
                    child: pw.Text(
                      h, 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                      textAlign: idx == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 6),
              // Items
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: keys.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final String k = entry.value.toString();
                      final String val = item[k]?.toString() ?? '';
                      return pw.Expanded(
                        flex: idx == 0 ? 3 : 1,
                        child: pw.Text(
                          val, 
                          style: const pw.TextStyle(fontSize: 11),
                          textAlign: idx == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('JAMI:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('$total $currency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.Spacer(), // Push footer to bottom
              pw.Center(
                child: pw.Text(footer, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
