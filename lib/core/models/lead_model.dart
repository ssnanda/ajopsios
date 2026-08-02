/// GET /ops/leads row shape (format_lead_row in class-ajcore-rest-api.php).
/// No server-side status/pipeline filter — matches AJOps web, which also
/// filters client-side over the full list.
class Lead {
  final int id;
  final String formTitle;
  final String status; // new | read | won | lost | duplicate
  final String leadStatus; // pipeline: new|auto_reached|engaged|tour|customer|future_follow_up|lost
  final String leadFollowUpAt;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String source;
  final String notes;
  final String createdAt;
  final String stripeCustomerId;
  final String customerName;
  final String siteLabel;
  final List<LeadNote> notesList;

  const Lead({
    required this.id,
    required this.formTitle,
    required this.status,
    required this.leadStatus,
    required this.leadFollowUpAt,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.source,
    required this.notes,
    required this.createdAt,
    required this.stripeCustomerId,
    required this.customerName,
    required this.siteLabel,
    required this.notesList,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      formTitle: json['form_title'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      leadStatus: json['lead_status'] as String? ?? 'new',
      leadFollowUpAt: json['lead_follow_up_at'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      company: json['company'] as String? ?? '',
      source: json['source'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      siteLabel: json['site_label'] as String? ?? '',
      notesList: (json['notes_list'] as List<dynamic>? ?? [])
          .map((e) => LeadNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayName => name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Lead #$id');
  bool get isWon => leadStatus == 'customer';
  bool get isLost => leadStatus == 'lost';

  // Keyed by id for Riverpod .family caching.
  @override
  bool operator ==(Object other) => other is Lead && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class LeadNote {
  final int id;
  final String note;
  final String authorName;
  final String createdAt;

  const LeadNote({required this.id, required this.note, required this.authorName, required this.createdAt});

  factory LeadNote.fromJson(Map<String, dynamic> json) => LeadNote(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        note: json['note'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

/// The pipeline order shown as a stage picker on the detail screen. "lost" is
/// a separate off-ramp, not a forward step — same convention as service
/// requests' "cancelled".
const leadPipelineStages = ['new', 'auto_reached', 'engaged', 'tour', 'future_follow_up', 'customer'];

const leadPipelineLabels = {
  'new': 'New',
  'auto_reached': 'Reached',
  'engaged': 'Engaged',
  'tour': 'Tour',
  'future_follow_up': 'Follow-up',
  'customer': 'Customer',
  'lost': 'Lost',
};
