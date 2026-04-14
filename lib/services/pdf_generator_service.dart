
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

    // Advanced item detection
    List<dynamic> items = data['items'] ?? data['rows'] ?? data['products'] ?? data['list'] ?? data['data'] ?? data['details'] ?? data['positions'] ?? data['items_list'] ?? data['students'] ?? [];
    if (items.isEmpty) {
      for (var value in data.values) {
        if (value is List && value.isNotEmpty) {
          items = value;
          break;
        }
      }
    }

    final String title = data['title'] ?? data['name'] ?? 'Baholar Ro\'yxati';
    final String subject = data['subject'] ?? data['fan'] ?? '';
    final String group = data['group'] ?? data['guruh'] ?? '';
    final String date = data['date'] ?? data['sana'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String teacher = data['teacher'] ?? data['o\'qituvchi'] ?? data['o_qituvchi'] ?? '';
    final String footerText = data['footer'] ?? data['tasdiq'] ?? "Tasdiqlayman: Baholarni aniq va to'g'ri ko'chirib chiqdim.";
    
    // Build subtitle strings like in screenshot
    String subtitle = "";
    if (subject.isNotEmpty) subtitle += "Fan: $subject";
    if (group.isNotEmpty) subtitle += (subtitle.isEmpty ? "" : " | ") + "Guruh: $group";

    String infoLine = "Sana: $date";
    if (data['total_count'] != null) infoLine += " | Jami: ${data['total_count']} talaba";
    if (data['graded_count'] != null) infoLine += " | Baholangan: ${data['graded_count']} ta";

    // Dynamic columns or defaults for education
    final List<dynamic> headers = data['headers'] ?? ['#', 'Talaba F.I.Sh.', 'Fan nomi', 'Guruh', 'Baho'];
    final List<dynamic> keys = data['keys'] ?? ['id', 'fullname', 'subject_name', 'group_name', 'grade'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (pw.Context context) {
          return [
            // Center Header
            pw.Center(
              child: pw.Column(
                children: [
                   pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                   pw.SizedBox(height: 6),
                   if (subtitle.isNotEmpty) pw.Text(subtitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                   pw.SizedBox(height: 4),
                   pw.Text(infoLine, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FixedColumnWidth(50),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: headers.map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                  )).toList(),
                ),
                // Table Rows
                ...items.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final dynamic item = entry.value;
                  return pw.TableRow(
                    children: keys.map((k) {
                      String val = "";
                      if (k == 'id' || k == '#') {
                        val = (index + 1).toString();
                      } else if (item is Map) {
                        val = item[k]?.toString() ?? "";
                      }
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(val, style: const pw.TextStyle(fontSize: 9), textAlign: (k == 'grade' || k == 'id' || k == '#') ? pw.TextAlign.center : pw.TextAlign.left),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
            
            pw.SizedBox(height: 40),
            
            // Footer section
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(footerText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        children: [
                          pw.Text("Imzo: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Sana: $date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 15),
                      pw.Text(teacher.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final int pageCount = pdf.document.pdfPageList.pages.length;
    return PdfGeneratorResponse(bytes, pageCount);
  }
}
