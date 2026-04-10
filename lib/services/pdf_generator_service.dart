
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
    final String title = data['title'] ?? data['store_name'] ?? 'Chek';
    final String address = data['address'] ?? '';
    final String date = data['date'] ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final String total = data['total']?.toString() ?? '0';
    final String currency = data['currency'] ?? "so'm";
    final String footer = data['footer'] ?? "Xaridingiz uchun rahmat!";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    if (address.isNotEmpty) pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(address, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(date, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Nomi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Container(width: 30, child: pw.Text('Soni', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Container(width: 50, child: pw.Text('Jami', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              // Items
              ...items.map((item) {
                final String name = item['name'] ?? item['title'] ?? 'Noma\'lum';
                final String qty = item['qty']?.toString() ?? item['quantity']?.toString() ?? '1';
                final String price = item['price']?.toString() ?? '0';
                final String itemTotal = item['total']?.toString() ?? '';

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(name, style: const pw.TextStyle(fontSize: 9))),
                      pw.Container(width: 30, child: pw.Text(qty, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      pw.Container(width: 50, child: pw.Text(itemTotal.isNotEmpty ? itemTotal : price, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                );
              }).toList(),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('JAMI:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('$total $currency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(footer, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
