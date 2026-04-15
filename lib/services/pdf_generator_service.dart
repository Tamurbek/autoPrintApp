
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

    // ---- DEBUG: serverdan kelgan JSON ni ko'rish ----
    debugPrint('=== PDF GENERATOR: rawData keys: ${rawData.keys.toList()} ===');
    debugPrint('=== PDF GENERATOR: rawData: $rawData ===');

    // 1. Ma'lumotlar qayerda joylashganini aniqlash (ustuvorlik: html -> data -> root)
    Map<String, dynamic> data = rawData;
    
    // Server ba'zan 'html' ichida asosiy JSON ni yuboradi
    if (rawData.containsKey('html')) {
      final htmlVal = rawData['html'];
      if (htmlVal is Map<String, dynamic>) {
        data = htmlVal;
        debugPrint('=== Using data from "html" map ===');
      } else if (htmlVal is String && htmlVal.trim().startsWith('{')) {
        try {
          data = jsonDecode(htmlVal) as Map<String, dynamic>;
          debugPrint('=== Using data from "html" JSON string ===');
        } catch (e) {
          debugPrint('=== Error parsing "html" string as JSON: $e ===');
        }
      }
    } else if (rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>) {
      data = rawData['data'] as Map<String, dynamic>;
      debugPrint('=== Using data from "data" map ===');
    }

    // 2. Items ro'yxatini topish — ko'plab nomlarni sinab ko'rishi
    List<dynamic> items = [];
    const candidateListKeys = [
      'items', 'rows', 'products', 'list', 'details',
      'positions', 'items_list', 'students', 'grades',
      'baholar', 'records', 'results', 'entries',
    ];
    
    // Avval 'data' ichidan qidiramiz
    for (final k in candidateListKeys) {
      if (data[k] is List) {
        items = data[k] as List<dynamic>;
        debugPrint('=== items found under key "$k", count: ${items.length} ===');
        break;
      }
    }

    // Agar topilmasa, butun rawData ichidan qidiramiz (nesting bo'lsa)
    if (items.isEmpty && data != rawData) {
       for (final k in candidateListKeys) {
        if (rawData[k] is List) {
          items = rawData[k] as List<dynamic>;
          debugPrint('=== items found under rawData key "$k", count: ${items.length} ===');
          break;
        }
      }
    }

    // Agar hali ham topilmasa — birinchi List qiymatni olish
    if (items.isEmpty) {
      for (final entry in data.entries) {
        if (entry.value is List && (entry.value as List).isNotEmpty) {
          items = entry.value as List<dynamic>;
          debugPrint('=== items found under key "${entry.key}" (fallback), count: ${items.length} ===');
          break;
        }
      }
    }

    // 3. Header va keys ni aniqlash
    List<dynamic> headers;
    List<dynamic> keys;

    if (data['headers'] is List && data['keys'] is List) {
      headers = data['headers'] as List<dynamic>;
      keys = data['keys'] as List<dynamic>;
    } else if (items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      keys = firstItem.keys.toList();
      headers = keys.map((k) {
        final s = k.toString().replaceAll('_', ' ');
        return s[0].toUpperCase() + s.substring(1);
      }).toList();

      // # raqam ustunini boshiga qo'shish (agar yo'q bo'lsa)
      if (!keys.contains('#') && !keys.contains('id') && !keys.contains('index')) {
        keys = ['#', ...keys];
        headers = ['#', ...headers];
      }
    } else {
      // Eng so'nggi fallback
      headers = ['#', 'Talaba F.I.Sh.', 'Fan nomi', 'Guruh', 'Baho'];
      keys = ['#', 'fullname', 'subject_name', 'group_name', 'grade'];
    }

    // 4. Meta maydonlarini olish (ham 'data', ham 'rawData' dan qidirish)
    final String title = _str(data, ['title', 'document_name']) ?? 
                       _str(rawData, ['document_name', 'title']) ?? 
                       "Baholar Ro'yxati";
    
    final info = data['info'] is Map ? data['info'] : (rawData['info'] is Map ? rawData['info'] : null);
    
    final String subject = _str(data, ['subject', 'fan']) ?? _str(info, ['fan', 'subject', 'name']) ?? '';
    final String group = _str(data, ['group', 'guruh']) ?? _str(info, ['guruh', 'group']) ?? '';
    final String date = _str(data, ['date', 'sana']) ?? _str(info, ['sana', 'date']) ?? 
                       DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String teacher = _str(data, ['teacher', "o'qituvchi"]) ?? _str(info, ['teacher', "o'qituvchi"]) ?? '';
    final String footerText = _str(data, ['footer', 'tasdiq']) ?? _str(info, ['footer']) ?? 
                             "Tasdiqlayman: Baholarni aniq va to'g'ri ko'chirib chiqdim.";

    String subtitle = "";
    if (subject.isNotEmpty) subtitle += "Fan: $subject";
    if (group.isNotEmpty) subtitle += (subtitle.isEmpty ? "" : " | ") + "Guruh: $group";

    String infoLine = "Sana: $date";
    final totalCount = data['total_count'] ?? data['count'] ?? info?['total_count'] ?? info?['jami_talaba'];
    final gradedCount = data['graded_count'] ?? info?['graded_count'] ?? info?['baholangan_count'];

    if (totalCount != null) infoLine += " | Jami: $totalCount talaba";
    if (gradedCount != null) infoLine += " | Baholangan: $gradedCount ta";

    debugPrint('=== title: $title, items count: ${items.length} ===');


    // 5. Ustun kengliklarini hisoblash
    final int colCount = headers.length;
    Map<int, pw.TableColumnWidth> columnWidths = {};
    for (int i = 0; i < colCount; i++) {
      final key = keys[i].toString();
      if (key == '#' || key == 'id') {
        columnWidths[i] = const pw.FixedColumnWidth(30);
      } else {
        columnWidths[i] = const pw.FlexColumnWidth(1);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  pw.SizedBox(height: 6),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Text(infoLine,
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Jadval
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: columnWidths,
              children: [
                // Sarlavha qatori
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: headers
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(h.toString(),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold, fontSize: 9),
                                textAlign: pw.TextAlign.center),
                          ))
                      .toList(),
                ),
                // Ma'lumot qatorlari
                ...items.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final dynamic item = entry.value;
                  return pw.TableRow(
                    children: keys.map((k) {
                      String val = "";
                      final keyStr = k.toString();
                      if (keyStr == '#' || keyStr == 'id') {
                        val = (index + 1).toString();
                      } else if (item is Map) {
                        // To'g'ridan-to'g'ri kalit bilan izlash
                        if (item.containsKey(keyStr)) {
                          val = item[keyStr]?.toString() ?? "";
                        } else {
                          // Kalit nomlarini moslash (professional nomlar -> technical keys)
                          final lk = keyStr.toLowerCase();
                          if (lk == 'fullname' || lk == 'talaba' || lk == 'f.i.sh.' || lk == 'fish') {
                             val = _str(item, ['fish', 'fullname', 'name', 'talaba', 'fullname_uz']) ?? "";
                          } else if (lk == 'subject' || lk == 'subject_name' || lk == 'fan' || lk == 'fan nomi') {
                             val = _str(item, ['subject', 'subject_name', 'fan', 'fan_nomi']) ?? "";
                          } else if (lk == 'group' || lk == 'group_name' || lk == 'guruh') {
                             val = _str(item, ['guruh', 'group', 'group_name', 'guruh_nomi']) ?? "";
                          } else if (lk == 'grade' || lk == 'baho' || lk == 'ball') {
                             val = _str(item, ['grade', 'baho', 'ball', 'mark']) ?? "";
                          } else {
                             // Hech biri bo'lmasa — kichik harfda qidirish
                             for (final itemKey in item.keys) {
                               if (itemKey.toString().toLowerCase() == lk) {
                                 val = item[itemKey]?.toString() ?? "";
                                 break;
                               }
                             }
                          }
                        }
                      }
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(val,
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: (keyStr == 'grade' ||
                                    keyStr == 'id' ||
                                    keyStr == '#' ||
                                    keyStr == 'baho')
                                ? pw.TextAlign.center
                                : pw.TextAlign.left),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 20),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(footerText,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        children: [
                          pw.Text("Imzo: ",
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Container(
                              width: 150,
                              decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide()))),
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
                      pw.Text("Sana: $date",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 15),
                      if (teacher.isNotEmpty)
                        pw.Text(teacher.toUpperCase(),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 12)),
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

  /// Xavfsiz string olish yordamchi funksiya
  static String? _str(dynamic source, List<String> keys) {
    if (source == null || source is! Map) return null;
    for (final k in keys) {
      if (source[k] != null && source[k].toString().isNotEmpty) {
        return source[k].toString();
      }
    }
    return null;
  }
}
