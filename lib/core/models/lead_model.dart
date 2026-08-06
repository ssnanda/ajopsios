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
  final String siteUuid;
  final String siteLabel;
  final List<LeadNote> notesList;
  /// The linear (non-terminal) LEAD STATUS stages for this lead's SITE, in order — e.g.
  /// University Office Suites includes "tour", other sites don't. Resolved by AJCore per-row
  /// (see get_lead_pipeline_linear_stages() in class-ajforms-admin.php) — mirrors AJOps web's
  /// Lead.leadPipelineStages. Falls back to the generic default when AJCore omits it.
  final List<String> leadPipelineStages;

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
    required this.siteUuid,
    required this.siteLabel,
    required this.notesList,
    required this.leadPipelineStages,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    final stages = (json['lead_pipeline_stages'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((s) => leadPipelineLabels.containsKey(s))
        .toList();
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
      siteUuid: json['site_uuid'] as String? ?? '',
      siteLabel: json['site_label'] as String? ?? '',
      notesList: (json['notes_list'] as List<dynamic>? ?? [])
          .map((e) => LeadNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      leadPipelineStages: (stages != null && stages.isNotEmpty)
          ? stages
          : defaultLeadPipelineStages,
    );
  }

  String get displayName => name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Lead #$id');
  bool get isWon => leadStatus == 'customer';
  bool get isLost => leadStatus == 'lost';
  bool get isDuplicate => status == 'duplicate';

  /// True while a Future Follow-Up lead's date hasn't arrived yet — once it's due, it's no longer "future".
  bool get isFutureFollowUp {
    if (leadStatus != 'future_follow_up' || leadFollowUpAt.isEmpty) return false;
    final due = DateTime.tryParse(leadFollowUpAt);
    return due != null && due.isAfter(DateTime.now());
  }

  /// Most recent staff note, excluding the auto-logged "Follow-up email sent." markers —
  /// matches AJOps web's "latest" note shown in the leads table. Null if there are none.
  LeadNote? get latestNote {
    final human = notesList.where((n) => !n.note.startsWith('Follow-up email sent')).toList();
    return human.isEmpty ? null : human.last;
  }

  /// "customer" is a branch endpoint reachable from Engaged onward, not a forward step in the
  /// walkable sequence — same convention as AJOps web's LeadStatusStepper (it's set only via the
  /// dedicated Customer action, which collects a linked customer, never by tapping a plain step).
  List<String> get linearPipelineStages =>
      leadPipelineStages.where((s) => s != 'customer').toList();

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

/// Fallback linear stage order used only when AJCore's row is missing
/// `lead_pipeline_stages` (older cached data) — normally each Lead carries its
/// own site-resolved list instead (see Lead.leadPipelineStages above).
const defaultLeadPipelineStages = ['new', 'auto_reached', 'engaged', 'customer'];

const leadPipelineLabels = {
  'new': 'New',
  'auto_reached': 'Reached',
  'engaged': 'Engaged',
  'tour': 'Tour',
  'future_follow_up': 'Follow-up',
  'customer': 'Customer',
  'lost': 'Lost',
};
