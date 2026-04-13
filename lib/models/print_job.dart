
class PrintJob {
  final String uuid;
  final String printerId;
  final String subjectId;
  final String type;
  final String html;
  final String documentName;
  final int copies;
  final String status;
  final String? createdAt;

  PrintJob({
    required this.uuid,
    required this.printerId,
    required this.subjectId,
    required this.type,
    required this.html,
    required this.documentName,
    this.copies = 1,
    required this.status,
    this.createdAt,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PrintJob(
      uuid: json['uuid'],
      printerId: json['printer_id'],
      subjectId: json['subject_id'],
      type: data['type'],
      html: data['html'],
      documentName: data['document_name'],
      copies: data['copies'] ?? 1,
      status: json['status'],
      createdAt: json['created_at'],
    );
  }
}

