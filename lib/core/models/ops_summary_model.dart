/// GET /ops/summary — raw table counts (see get_ops_summary in
/// class-ajcore-rest-api.php). Kept intentionally thin — the AJOps web
/// dashboard itself only surfaces customers/tasks/service_requests today.
class OpsSummaryModel {
  final int customers;
  final int products;
  final int subscriptions;
  final int tasks;
  final int serviceRequests;

  const OpsSummaryModel({
    required this.customers,
    required this.products,
    required this.subscriptions,
    required this.tasks,
    required this.serviceRequests,
  });

  factory OpsSummaryModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return OpsSummaryModel(
      customers: asInt(json['customers']),
      products: asInt(json['products']),
      subscriptions: asInt(json['subscriptions']),
      tasks: asInt(json['tasks']),
      serviceRequests: asInt(json['service_requests']),
    );
  }
}
