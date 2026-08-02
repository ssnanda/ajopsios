/// GET /ops/chat/sessions/{id}/messages row shape — mirrors
/// format_chat_message_row() in class-ajcore-rest-api.php.
class ChatMessage {
  final int id;
  final int sessionId;
  final String senderType; // "visitor" | "staff"
  final String senderName;
  final String body;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        sessionId: int.tryParse(json['sessionId']?.toString() ?? '0') ?? 0,
        senderType: json['senderType'] as String? ?? 'visitor',
        senderName: json['senderName'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  bool get isStaff => senderType == 'staff';
}
