import 'api_client.dart';
import 'api_endpoints.dart';
import '../models/ops_summary_model.dart';
import '../models/ops_service_request_model.dart';
import '../models/service_request_history_model.dart';
import '../models/staff_model.dart';

/// Thin wrapper around the shared Dio client for the `/ops/*` endpoints.
/// Mirrors AJOps' own AJCoreClient (ajops/src/lib/ajcore/client.ts) so both
/// clients stay behaviorally identical against the same backend.
class OpsApi {
  OpsApi._();
  static final OpsApi instance = OpsApi._();

  Future<OpsSummaryModel> getSummary() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.summary);
    return OpsSummaryModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<StaffModel>> getStaff() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.staff);
    final list = (resp.data as Map<String, dynamic>)['staff'] as List<dynamic>? ?? [];
    return list.map((e) => StaffModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<(List<OpsServiceRequest>, OpsServiceRequestStats)> getServiceRequests({
    String? status,
    String? source,
    String? search,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.serviceRequests,
      queryParameters: {
        if (status != null) 'request_status': status,
        if (source != null) 'sr_source': source,
        if (search != null && search.isNotEmpty) 's': search,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final rows = (data['service_requests'] as List<dynamic>? ?? [])
        .map((e) => OpsServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    final stats = OpsServiceRequestStats.fromJson(
      data['stats'] as Map<String, dynamic>? ?? {},
    );
    return (rows, stats);
  }

  /// Update one request's pay status / service status / admin notes / a new
  /// history note / assignee — same single endpoint used by the stepper,
  /// the assignee dropdown, and the notes form on both web apps.
  Future<void> updateServiceRequest(
    int id, {
    String? status,
    String? serviceStatus,
    String? adminNotes,
    String? note,
    int? assignedUserId,
  }) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.updateServiceRequest(id),
      data: {
        if (status != null) 'status': status,
        if (serviceStatus != null) 'serviceStatus': serviceStatus,
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (note != null) 'note': note,
        if (assignedUserId != null) 'assignedUserId': assignedUserId,
      },
    );
  }

  Future<List<ServiceRequestHistoryEntry>> getServiceRequestHistory(int id) async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.serviceRequestHistory(id));
    final list = (resp.data as Map<String, dynamic>)['history'] as List<dynamic>? ?? [];
    return list.map((e) => ServiceRequestHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> bulkUpdateServiceRequests(
    List<int> ids, {
    String? serviceStatus,
    int? assignedUserId,
  }) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.serviceRequestsBulk,
      data: {
        'ids': ids,
        if (serviceStatus != null) 'service_status': serviceStatus,
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
      },
    );
  }
}
