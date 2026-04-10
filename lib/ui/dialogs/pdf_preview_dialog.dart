
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewDialog extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfPreviewDialog({
    super.key,
    required this.pdfBytes,
    this.title = 'Hujjat ko\'rinishi',
  });

  static void show(BuildContext context, Uint8List pdfBytes, {String? title}) {
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(pdfBytes: pdfBytes, title: title ?? 'Hujjat ko\'rinishi'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PdfPreview(
                  build: (format) => pdfBytes,
                  useActions: false, // Disable all actions (print, share, etc. from toolbar)
                  allowPrinting: false,
                  allowSharing: false,
                  canDebug: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  // The following might help on some platforms to prevent text selection
                  // though pdfpreview doesn't have a direct 'noSelect' prop.
                  // But by disabling actions, it's mostly a viewer.
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Tushunarli'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
