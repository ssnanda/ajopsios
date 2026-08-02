/// GET /ops/gmail-intake row shape (format_gmail_intake_log_row in
/// class-ajcore-rest-api.php).
class GmailIntakeItem {
  final int id;
  final String subject;
  final String sender;
  final String snippet;
  final String companyNameExtracted;
  final String status; // filed | matched_pending_file | skipped_no_attachment | needs_review | resolved
  final String stripeCustomerId;
  final String customerName;
  final List<String> filedFilenames;
  final String errorMessage;
  final String receivedAt;

  const GmailIntakeItem({
    required this.id,
    required this.subject,
    required this.sender,
    required this.snippet,
    required this.companyNameExtracted,
    required this.status,
    required this.stripeCustomerId,
    required this.customerName,
    required this.filedFilenames,
    required this.errorMessage,
    required this.receivedAt,
  });

  factory GmailIntakeItem.fromJson(Map<String, dynamic> json) {
    return GmailIntakeItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      subject: json['subject'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      companyNameExtracted: json['company_name_extracted'] as String? ?? '',
      status: json['status'] as String? ?? 'needs_review',
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      filedFilenames: (json['filed_filenames'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      errorMessage: json['error_message'] as String? ?? '',
      receivedAt: json['received_at'] as String? ?? '',
    );
  }
}

/// GET /ops/gmail-intake/{id}/preview response.
class GmailIntakePreview {
  final String subject;
  final String sender;
  final String date;
  final String body;
  final List<GmailIntakeAttachment> attachments;

  const GmailIntakePreview({
    required this.subject,
    required this.sender,
    required this.date,
    required this.body,
    required this.attachments,
  });

  factory GmailIntakePreview.fromJson(Map<String, dynamic> json) {
    return GmailIntakePreview(
      subject: json['subject'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      date: json['date'] as String? ?? '',
      body: json['body'] as String? ?? '',
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => GmailIntakeAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GmailIntakeAttachment {
  final String attachmentId;
  final String filename;

  const GmailIntakeAttachment({required this.attachmentId, required this.filename});

  factory GmailIntakeAttachment.fromJson(Map<String, dynamic> json) => GmailIntakeAttachment(
        attachmentId: json['attachment_id']?.toString() ?? '',
        filename: json['filename'] as String? ?? '',
      );
}
