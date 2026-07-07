/// GET /ops/service-requests row shape — mirrors AJOps' RawServiceRequest /
/// ServiceRequest types (ajops/src/lib/ajcore/types.ts) exactly, since both
/// clients read the same endpoint.
class OpsServiceRequest {
  final int id;
  final String stripeCustomerId;
  final String serviceName;
  final String requestType;
  final String status; // "pay status"
  final String serviceStatus; // "svc status" — drives the stepper
  final double amount;
  final String currency;
  final String source;
  final String sourceType;
  final String clientNotes;
  final String adminNotes;
  final String createdAt;
  final String updatedAt;
  final String customerName;
  final String customerEmail;
  final bool needsAction;
  final int assignedUserId;
  final String assignedUserName;
  final String assignedUserEmail;
  final Map<String, String> serviceStatusOptions; // ordered key -> label, drives the stepper
  final Map<String, String> quickActions; // action key -> button label

  const OpsServiceRequest({
    required this.id,
    required this.stripeCustomerId,
    required this.serviceName,
    required this.requestType,
    required this.status,
    required this.serviceStatus,
    required this.amount,
    required this.currency,
    required this.source,
    required this.sourceType,
    required this.clientNotes,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.customerName,
    required this.customerEmail,
    required this.needsAction,
    required this.assignedUserId,
    required this.assignedUserName,
    required this.assignedUserEmail,
    required this.serviceStatusOptions,
    required this.quickActions,
  });

  factory OpsServiceRequest.fromJson(Map<String, dynamic> json) {
    Map<String, String> asStringMap(dynamic v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val.toString()));
      }
      return {};
    }

    return OpsServiceRequest(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      serviceName: json['service_name'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      serviceStatus: json['service_status'] as String? ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency'] as String? ?? 'usd',
      source: json['source'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
      clientNotes: json['client_notes'] as String? ?? '',
      adminNotes: json['admin_notes'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      needsAction: json['needs_action'] == true,
      assignedUserId: int.tryParse(json['assigned_user_id']?.toString() ?? '0') ?? 0,
      assignedUserName: json['assigned_user_name'] as String? ?? '',
      assignedUserEmail: json['assigned_user_email'] as String? ?? '',
      serviceStatusOptions: asStringMap(json['service_status_options']),
      quickActions: asStringMap(json['quick_actions']),
    );
  }

  /// The forward pipeline for the stepper — same rule as both web apps:
  /// "cancelled" is a separate off-ramp, not a step in the linear sequence.
  List<MapEntry<String, String>> get pipelineSteps =>
      serviceStatusOptions.entries.where((e) => e.key != 'cancelled').toList();

  bool get hasCancelOption => serviceStatusOptions.containsKey('cancelled');
}

class OpsServiceRequestStats {
  final int total;
  final int needsAction;
  final int active;
  final int completed;
  final int shown;

  const OpsServiceRequestStats({
    required this.total,
    required this.needsAction,
    required this.active,
    required this.completed,
    required this.shown,
  });

  factory OpsServiceRequestStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return OpsServiceRequestStats(
      total: asInt(json['total']),
      needsAction: asInt(json['needs_action']),
      active: asInt(json['active']),
      completed: asInt(json['completed']),
      shown: asInt(json['shown']),
    );
  }

  static const empty = OpsServiceRequestStats(total: 0, needsAction: 0, active: 0, completed: 0, shown: 0);
}
