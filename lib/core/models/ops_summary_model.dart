/// GET /ops/summary — raw table counts (see get_ops_summary in
/// class-ajcore-rest-api.php).
class OpsSummaryModel {
  final int customers;
  final int products;
  final int subscriptions;
  final int tasks;
  final int tasksOpen;
  final int serviceRequests;
  final int serviceRequestsNeedsAction;
  final int leads;
  final int leadsUnread;
  final int leadsActive;
  final int chatUnread;

  const OpsSummaryModel({
    required this.customers,
    required this.products,
    required this.subscriptions,
    required this.tasks,
    required this.tasksOpen,
    required this.serviceRequests,
    required this.serviceRequestsNeedsAction,
    required this.leads,
    required this.leadsUnread,
    required this.leadsActive,
    required this.chatUnread,
  });

  OpsSummaryModel copyWith({int? leadsActive}) {
    return OpsSummaryModel(
      customers: customers,
      products: products,
      subscriptions: subscriptions,
      tasks: tasks,
      tasksOpen: tasksOpen,
      serviceRequests: serviceRequests,
      serviceRequestsNeedsAction: serviceRequestsNeedsAction,
      leads: leads,
      leadsUnread: leadsUnread,
      leadsActive: leadsActive ?? this.leadsActive,
      chatUnread: chatUnread,
    );
  }

  factory OpsSummaryModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return OpsSummaryModel(
      customers: asInt(json['customers']),
      products: asInt(json['products']),
      subscriptions: asInt(json['subscriptions']),
      tasks: asInt(json['tasks']),
      tasksOpen: asInt(json['tasks_open']),
      serviceRequests: asInt(json['service_requests']),
      serviceRequestsNeedsAction: asInt(json['service_requests_needs_action']),
      leads: asInt(json['leads']),
      leadsUnread: asInt(json['leads_unread']),
      leadsActive: asInt(json['leads_active']),
      chatUnread: asInt(json['chat_unread']),
    );
  }
}
