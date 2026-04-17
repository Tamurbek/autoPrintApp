
import 'dart:typed_data';

class PrintJob {
  final String uuid;
  final String printerId;
  final String? subjectId;
  final String type;
  final String? html;
  final String? base64Data;
  final String documentName;
  final int copies;
  final String status;
  final String? createdAt;
  
  // Non-final field to store temporary data
  Uint8List? pdfBytes;

  PrintJob({
    required this.uuid,
    required this.printerId,
    this.subjectId,
    required this.type,
    this.html,
    this.base64Data,
    required this.documentName,
    this.copies = 1,
    required this.status,
    this.createdAt,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return PrintJob(
      uuid: json['uuid'] ?? '',
      printerId: json['printer_id'] ?? '',
      subjectId: json['subject_id'],
      type: data['type'] ?? '',
      html: data['html'],
      base64Data: data['base64_data'],
      documentName: data['document_name'] ?? 'Hujjat',
      copies: data['copies'] ?? 1,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'],
    );
  }
}

