/// GET /ops/service-requests/{id}/history entry — title is pre-resolved
/// server-side (get_portal_service_request_history_title), same as both web apps.
class ServiceRequestHistoryEntry {
  final int id;
  final String eventType;
  final String title;
  final String statusBefore;
  final String statusAfter;
  final String serviceStatusBefore;
  final String serviceStatusAfter;
  final String note;
  final String actorEmail;
  final String createdAt;

  const ServiceRequestHistoryEntry({
    required this.id,
    required this.eventType,
    required this.title,
    required this.statusBefore,
    required this.statusAfter,
    required this.serviceStatusBefore,
    required this.serviceStatusAfter,
    required this.note,
    required this.actorEmail,
    required this.createdAt,
  });

  factory ServiceRequestHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ServiceRequestHistoryEntry(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      statusBefore: json['status_before'] as String? ?? '',
      statusAfter: json['status_after'] as String? ?? '',
      serviceStatusBefore: json['service_status_before'] as String? ?? '',
      serviceStatusAfter: json['service_status_after'] as String? ?? '',
      note: json['note'] as String? ?? '',
      actorEmail: json['actor_email'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
