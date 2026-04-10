
import 'package:flutter/material.dart';

class PrintConfirmationDialog extends StatelessWidget {
  final int? pageCount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PrintConfirmationDialog({
    super.key,
    required this.pageCount,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<bool?> show(BuildContext context, int? pageCount) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrintConfirmationDialog(
        pageCount: pageCount,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.print_rounded, color: Color(0xFF6366F1)),
          SizedBox(width: 12),
          Text("Chop etishni tasdiqlang"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pageCount != null 
              ? "Ushbu hujjat $pageCount betdan iborat." 
              : "Hujjat tayyorlandi.",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text("Printerda yetarli qog'oz borligini tekshiring va chop etishni tasdiqlang."),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text("Bekor qilish", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          child: const Text("Chop etish"),
        ),
      ],
    );
  }
}
