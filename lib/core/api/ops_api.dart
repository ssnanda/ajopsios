import 'api_client.dart';
import 'api_endpoints.dart';
import '../models/ops_summary_model.dart';
import '../models/ops_service_request_model.dart';
import '../models/service_request_history_model.dart';
import '../models/staff_model.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/upos_device_model.dart';

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

  // ── Live Chat ────────────────────────────────────────────────────────────

  Future<List<ChatSession>> getChatSessions({String? status}) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.chatSessions,
      queryParameters: {
        if (status != null) 'status': status,
        'per_page': '200',
      },
    );
    final list = (resp.data as Map<String, dynamic>)['sessions'] as List<dynamic>? ?? [];
    return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> getChatSessionMessages(int id) async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.chatSessionMessages(id));
    final list = (resp.data as Map<String, dynamic>)['messages'] as List<dynamic>? ?? [];
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> replyToChatSession(int id, String body) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.chatSessionReply(id),
      data: {'body': body},
    );
    return ChatMessage.fromJson((resp.data as Map<String, dynamic>)['message'] as Map<String, dynamic>);
  }

  Future<ChatSession> claimChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(ApiEndpoints.chatSessionClaim(id));
    return ChatSession.fromJson((resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>);
  }

  Future<ChatSession> unclaimChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(ApiEndpoints.chatSessionUnclaim(id));
    return ChatSession.fromJson((resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>);
  }

  Future<ChatSession> closeChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(ApiEndpoints.chatSessionClose(id));
    return ChatSession.fromJson((resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>);
  }

  // ── UPOS Temps ───────────────────────────────────────────────────────────

  Future<(List<UposDevice>, UposSettingsStatus)> getUposTemps() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.uposTemps);
    final data = resp.data as Map<String, dynamic>;
    final devices = (data['devices'] as List<dynamic>? ?? [])
        .map((e) => UposDevice.fromJson(e as Map<String, dynamic>))
        .toList();
    final settings = UposSettingsStatus.fromJson(data['settings'] as Map<String, dynamic>? ?? {});
    return (devices, settings);
  }

  /// deviceId null = bulk (every configured device) — AJCore exposes these as
  /// separate route sets, not one endpoint with an optional deviceId.
  Future<void> setUposSystemMode(String mode, {String? deviceId}) async {
    final path = deviceId == null ? ApiEndpoints.uposTempsSystemBulk : ApiEndpoints.uposTempsDeviceSystem(deviceId);
    await ApiClient.instance.dio.post(path, data: {'mode': mode});
  }

  Future<void> setUposFanMode(String mode, {String? deviceId}) async {
    final path = deviceId == null ? ApiEndpoints.uposTempsFanBulk : ApiEndpoints.uposTempsDeviceFan(deviceId);
    await ApiClient.instance.dio.post(path, data: {'mode': mode});
  }
}
