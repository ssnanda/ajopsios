/// GET /ops/chat/sessions row shape — mirrors format_chat_session_row() in
/// class-ajcore-rest-api.php (camelCase JSON), the same shape AJOps' own
/// web client reads.
class ChatSession {
  final int id;
  final String siteUuid;
  final String siteLabel;
  final String sessionUuid;
  final String visitorName;
  final String visitorEmail;
  final String visitorPhone;
  final String status; // "open" | "closed"
  final String createdAt;
  final String lastMessageAt;
  final String closedAt;
  final int? assignedStaffId;
  final String assignedStaffName;
  final bool automationMuted;

  const ChatSession({
    required this.id,
    required this.siteUuid,
    required this.siteLabel,
    required this.sessionUuid,
    required this.visitorName,
    required this.visitorEmail,
    required this.visitorPhone,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    required this.closedAt,
    required this.assignedStaffId,
    required this.assignedStaffName,
    required this.automationMuted,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawStaffId = json['assignedStaffId'];
    return ChatSession(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      siteUuid: json['siteUuid'] as String? ?? '',
      siteLabel: json['siteLabel'] as String? ?? '',
      sessionUuid: json['sessionUuid'] as String? ?? '',
      visitorName: json['visitorName'] as String? ?? '',
      visitorEmail: json['visitorEmail'] as String? ?? '',
      visitorPhone: json['visitorPhone'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['createdAt'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] as String? ?? '',
      closedAt: json['closedAt'] as String? ?? '',
      assignedStaffId: rawStaffId == null ? null : int.tryParse(rawStaffId.toString()),
      assignedStaffName: json['assignedStaffName'] as String? ?? '',
      automationMuted: json['automationMuted'] == true,
    );
  }

  String get displayName =>
      visitorName.isNotEmpty ? visitorName : (visitorEmail.isNotEmpty ? visitorEmail : 'Visitor');

  bool get isOpen => status == 'open';
  bool get isAssigned => assignedStaffId != null && assignedStaffId != 0;

  // Keyed by id for Riverpod .family caching — a freshly-fetched ChatSession
  // instance for the same conversation should reuse the same provider entry.
  @override
  bool operator ==(Object other) => other is ChatSession && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
