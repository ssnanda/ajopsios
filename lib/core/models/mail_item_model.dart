/// GET /ops/mail row shape (format_mail_item_row in class-ajcore-rest-api.php).
class MailItem {
  final int id;
  final String mailUuid;
  final String stripeCustomerId;
  final String customerName;
  final String customerEmail;
  final String recipientName;
  final String mailType; // letter | legal | government | package | check | other
  final bool isSop;
  final String senderName;
  final String carrier;
  final String trackingNumber;
  final String description;
  final String status; // received | scanned | notified | closed
  final String disposition;
  final String scanUrl;
  final String receivedAt;
  final String createdAt;

  const MailItem({
    required this.id,
    required this.mailUuid,
    required this.stripeCustomerId,
    required this.customerName,
    required this.customerEmail,
    required this.recipientName,
    required this.mailType,
    required this.isSop,
    required this.senderName,
    required this.carrier,
    required this.trackingNumber,
    required this.description,
    required this.status,
    required this.disposition,
    required this.scanUrl,
    required this.receivedAt,
    required this.createdAt,
  });

  factory MailItem.fromJson(Map<String, dynamic> json) {
    return MailItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mailUuid: json['mail_uuid'] as String? ?? '',
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      mailType: json['mail_type'] as String? ?? 'letter',
      isSop: json['is_sop'] == true,
      senderName: json['sender_name'] as String? ?? '',
      carrier: json['carrier'] as String? ?? '',
      trackingNumber: json['tracking_number'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'received',
      disposition: json['disposition'] as String? ?? '',
      scanUrl: json['scan_url'] as String? ?? '',
      receivedAt: json['received_at'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

const mailTypes = ['letter', 'legal', 'government', 'package', 'check', 'other'];
