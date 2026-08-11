import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_interceptors.dart';
import '../models/ops_summary_model.dart';
import '../models/ops_service_request_model.dart';
import '../models/service_request_history_model.dart';
import '../models/staff_model.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/upos_device_model.dart';
import '../models/lead_model.dart';
import '../models/connected_site_model.dart';
import '../models/customer_model.dart';
import '../models/mail_item_model.dart';
import '../models/customer_file_model.dart';
import '../models/gmail_intake_item_model.dart';
import '../models/visitor_model.dart';
import '../models/api_status_model.dart';

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

  /// AJCore's configured business timezone, among other status fields — see
  /// siteStatusProvider for the cached/shared way screens should read this
  /// rather than every widget calling this directly.
  Future<ApiStatusModel> getStatus() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.status);
    return ApiStatusModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<StaffModel>> getStaff() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.staff);
    final list =
        (resp.data as Map<String, dynamic>)['staff'] as List<dynamic>? ?? [];
    return list
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<(List<OpsServiceRequest>, OpsServiceRequestStats)> getServiceRequests({
    String? status,
    String? source,
    String? search,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.serviceRequests,
      queryParameters: {
        if (status != null) 'status': status,
        if (source != null) 'source': source,
        if (search != null && search.isNotEmpty) 'search': search,
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
  Future<String> updateServiceRequest(
    int id, {
    String? status,
    String? serviceStatus,
    String? adminNotes,
    String? note,
    int? assignedUserId,
  }) async {
    final response = await ApiClient.instance.dio.post(
      ApiEndpoints.updateServiceRequest(id),
      data: {
        if (status != null) 'status': status,
        if (serviceStatus != null) 'service_status': serviceStatus,
        if (adminNotes != null) 'admin_notes': adminNotes,
        if (note != null) 'note': note,
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const ApiException(
        statusCode: 502,
        message: 'AJCore returned an invalid service-request response.',
      );
    }
    final updated = data['service_request'];
    if (updated is Map) {
      return updated['service_status']?.toString() ?? serviceStatus ?? '';
    }
    if (data['success'] == true && serviceStatus != null) {
      return serviceStatus;
    }
    throw const ApiException(
      statusCode: 502,
      message: 'AJCore did not confirm the service-request update.',
    );
  }

  Future<void> notifyServiceRequest(int id) async {
    await ApiClient.instance.dio.post(ApiEndpoints.serviceRequestNotify(id));
  }

  Future<void> applyServiceRequestQuickAction(int id, String action) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.serviceRequestQuickAction(id),
      data: {'action': action},
    );
  }

  Future<List<ServiceRequestHistoryEntry>> getServiceRequestHistory(
    int id,
  ) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.serviceRequestHistory(id),
    );
    final list =
        (resp.data as Map<String, dynamic>)['history'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ServiceRequestHistoryEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> bulkUpdateServiceRequests(
    List<int> ids, {
    String? serviceStatus,
    int? assignedUserId,
  }) async {
    final response = await ApiClient.instance.dio.post(
      ApiEndpoints.serviceRequestsBulk,
      data: {
        'ids': ids,
        if (serviceStatus != null) 'service_status': serviceStatus,
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
      },
    );
    final data = response.data;
    if (data is Map && data['success'] == false) {
      final failed = int.tryParse(data['failed']?.toString() ?? '') ?? 0;
      throw ApiException(
        statusCode: 400,
        message: failed > 0
            ? 'AJCore could not update $failed selected service request(s).'
            : 'AJCore could not update the selected service requests.',
      );
    }
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
    final list =
        (resp.data as Map<String, dynamic>)['sessions'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [online] true = "Live Monitor" (currently connected — ended_at IS NULL on their latest AJCore
  /// visit row); omitted/false = full Visitor History. Same /ops/visitors endpoint either way — see
  /// get_ops_visitor_history() in class-ajcore-rest-api.php.
  Future<List<Visitor>> getVisitors({bool? online, String? search}) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.visitors,
      queryParameters: {
        if (online == true) 'online': '1',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list =
        (resp.data as Map<String, dynamic>)['visitors'] as List<dynamic>? ?? [];
    return list.map((e) => Visitor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkVisitor(
    String visitorUuid, {
    String? stripeCustomerId,
    int? leadId,
  }) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.visitorLink(visitorUuid),
      data: {
        if (stripeCustomerId != null) 'stripe_customer_id': stripeCustomerId,
        if (leadId != null) 'lead_id': leadId,
      },
    );
  }

  Future<void> unlinkVisitor(String visitorUuid) async {
    await ApiClient.instance.dio.post(ApiEndpoints.visitorUnlink(visitorUuid));
  }

  Future<List<ChatMessage>> getChatSessionMessages(int id) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.chatSessionMessages(id),
    );
    final list =
        (resp.data as Map<String, dynamic>)['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> replyToChatSession(int id, String body) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.chatSessionReply(id),
      data: {'body': body},
    );
    return ChatMessage.fromJson(
      (resp.data as Map<String, dynamic>)['message'] as Map<String, dynamic>,
    );
  }

  Future<ChatSession> claimChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.chatSessionClaim(id),
    );
    return ChatSession.fromJson(
      (resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>,
    );
  }

  Future<ChatSession> unclaimChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.chatSessionUnclaim(id),
    );
    return ChatSession.fromJson(
      (resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>,
    );
  }

  Future<ChatSession> closeChatSession(int id) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.chatSessionClose(id),
    );
    return ChatSession.fromJson(
      (resp.data as Map<String, dynamic>)['session'] as Map<String, dynamic>,
    );
  }

  // ── UPOS Temps ───────────────────────────────────────────────────────────

  Future<(List<UposDevice>, UposSettingsStatus)> getUposTemps() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.uposTemps);
    final data = resp.data as Map<String, dynamic>;
    final devices = (data['devices'] as List<dynamic>? ?? [])
        .map((e) => UposDevice.fromJson(e as Map<String, dynamic>))
        .toList();
    final settings = UposSettingsStatus.fromJson(
      data['settings'] as Map<String, dynamic>? ?? {},
    );
    return (devices, settings);
  }

  /// deviceId null = bulk (every configured device) — AJCore exposes these as
  /// separate route sets, not one endpoint with an optional deviceId.
  Future<void> setUposSystemMode(
    String mode, {
    String? deviceId,
    List<String>? deviceIds,
  }) async {
    final path = deviceId == null
        ? ApiEndpoints.uposTempsSystemBulk
        : ApiEndpoints.uposTempsDeviceSystem(deviceId);
    await ApiClient.instance.dio.post(
      path,
      data: {
        'mode': mode,
        if (deviceId == null && deviceIds != null) 'device_ids': deviceIds,
      },
    );
  }

  Future<void> setUposFanMode(
    String mode, {
    String? deviceId,
    List<String>? deviceIds,
  }) async {
    final path = deviceId == null
        ? ApiEndpoints.uposTempsFanBulk
        : ApiEndpoints.uposTempsDeviceFan(deviceId);
    await ApiClient.instance.dio.post(
      path,
      data: {
        'mode': mode,
        if (deviceId == null && deviceIds != null) 'device_ids': deviceIds,
      },
    );
  }

  // ── Leads ────────────────────────────────────────────────────────────────
  // No server-side status/pipeline filter — AJOps web filters client-side over
  // the full list too, so this mirrors that rather than being a mobile gap.

  Future<List<Lead>> getLeads({String? search}) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.leads,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'per_page': '500',
      },
    );
    final list =
        (resp.data as Map<String, dynamic>)['leads'] as List<dynamic>? ?? [];
    return list.map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Same field set as AJOps web's New Lead form — POST /ops/leads.
  Future<Lead> createLead({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? source,
    String? notes,
    String? siteUuid,
  }) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.leads,
      data: {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (company != null && company.isNotEmpty) 'company': company,
        if (source != null && source.isNotEmpty) 'source': source,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (siteUuid != null && siteUuid.isNotEmpty) 'site_uuid': siteUuid,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    return Lead.fromJson(data['lead'] as Map<String, dynamic>);
  }

  Future<Lead> getLead(int id) async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.lead(id));
    final data = resp.data as Map<String, dynamic>;
    return Lead.fromJson(data['lead'] as Map<String, dynamic>);
  }

  Future<void> addLeadNote(int id, String note) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.leadNotes(id),
      data: {'note': note},
    );
  }

  /// Same field set AJOps web's Edit Lead form saves (name/email/phone/company/
  /// source/notes/site) — PATCH /ops/leads/{id}. Only non-null fields are sent.
  Future<Lead> updateLead(
    int id, {
    String? name,
    String? email,
    String? phone,
    String? company,
    String? source,
    String? notes,
    String? siteUuid,
  }) async {
    final resp = await ApiClient.instance.dio.patch(
      ApiEndpoints.lead(id),
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (company != null) 'company': company,
        if (source != null) 'source': source,
        if (notes != null) 'notes': notes,
        if (siteUuid != null) 'site_uuid': siteUuid,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    return Lead.fromJson(data['lead'] as Map<String, dynamic>);
  }

  /// Site drives which pipeline a lead walks (see leadPipelineStages on
  /// lead_model.dart) — same GET /ops/sites AJOps web's site picker reads.
  Future<List<ConnectedSite>> getConnectedSites() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.sites);
    final list =
        (resp.data as Map<String, dynamic>)['sites'] as List<dynamic>? ?? [];
    return list
        .map((e) => ConnectedSite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Advances (or reverts) the pipeline stage — the same endpoint AJOps' web
  /// stage-stepper uses. followUpAt only meaningful for "future_follow_up".
  Future<String> setLeadPipelineStatus(
    int id,
    String leadStatus, {
    String? note,
    String? stripeCustomerId,
    String? followUpAt,
    String? nonStripeCustomerName,
  }) async {
    final response = await ApiClient.instance.dio.patch(
      ApiEndpoints.leadPipelineStatus(id),
      data: {
        'lead_status': leadStatus,
        if (note != null) 'note': note,
        if (stripeCustomerId != null) 'stripe_customer_id': stripeCustomerId,
        if (followUpAt != null) 'follow_up_at': followUpAt,
        if (nonStripeCustomerName != null) 'non_stripe_customer_name': nonStripeCustomerName,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const ApiException(
        statusCode: 502,
        message: 'AJCore returned an invalid lead-status response.',
      );
    }
    final persistedStatus = data['lead_status']?.toString() ?? '';
    if (persistedStatus != leadStatus) {
      throw ApiException(
        statusCode: 502,
        message: 'AJCore did not save the requested lead status ($leadStatus).',
      );
    }
    return persistedStatus;
  }

  // ── Customers ────────────────────────────────────────────────────────────

  Future<List<Customer>> getCustomers({String? search}) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.customers,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'per_page': '500',
      },
    );
    final data = resp.data;
    final list = data is Map
        ? (data['customers'] as List<dynamic>? ?? const [])
        : (data is List ? data : const <dynamic>[]);
    return list
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerDetail> getCustomerDetail(String stripeCustomerId) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.customer(stripeCustomerId),
    );
    return CustomerDetail.fromJson(resp.data as Map<String, dynamic>);
  }

  /// action: enable | disable | archive | restore | reset_password | send_welcome
  Future<void> runCustomerAction(String stripeCustomerId, String action) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.customerAction(stripeCustomerId),
      data: {'action': action},
    );
  }

  // ── Mail ─────────────────────────────────────────────────────────────────

  Future<(List<MailItem>, Map<String, int>)> getMailItems({
    String? search,
    String? status,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.mail,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'per_page': '200',
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final items = (data['mail_items'] as List<dynamic>? ?? [])
        .map((e) => MailItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final statsJson = data['stats'] as Map<String, dynamic>? ?? {};
    final stats = statsJson.map(
      (k, v) => MapEntry(k, int.tryParse(v?.toString() ?? '0') ?? 0),
    );
    return (items, stats);
  }

  /// Multipart create — "scan" is a file field (image/PDF), everything else
  /// is a plain string field. scanFilePath null = no scan attached yet.
  Future<MailItem> createMailItem({
    required String recipientName,
    required String mailType,
    String? senderName,
    String? carrier,
    String? trackingNumber,
    String? description,
    String? stripeCustomerId,
    String? scanFilePath,
  }) async {
    final form = FormData.fromMap({
      'recipient_name': recipientName,
      'mail_type': mailType,
      if (senderName != null && senderName.isNotEmpty)
        'sender_name': senderName,
      if (carrier != null && carrier.isNotEmpty) 'carrier': carrier,
      if (trackingNumber != null && trackingNumber.isNotEmpty)
        'tracking_number': trackingNumber,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (stripeCustomerId != null && stripeCustomerId.isNotEmpty)
        'stripe_customer_id': stripeCustomerId,
      if (scanFilePath != null)
        'scan': await MultipartFile.fromFile(scanFilePath),
    });
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.mail,
      data: form,
    );
    return MailItem.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Files ────────────────────────────────────────────────────────────────

  Future<List<CustomerFile>> getFiles({
    String? search,
    String? category,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.files,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
        'per_page': '200',
      },
    );
    final list =
        (resp.data as Map<String, dynamic>)['files'] as List<dynamic>? ?? [];
    return list
        .map((e) => CustomerFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Multipart create — "file" is the attachment field, everything else is a
  /// plain string field. assignedEmails is a space/comma/semicolon-separated
  /// list (matches AJOps web), not a JSON array.
  Future<CustomerFile> createFile({
    required String filePath,
    String? title,
    String? category,
    String? description,
    String? assignedEmails,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (title != null && title.isNotEmpty) 'title': title,
      if (category != null && category.isNotEmpty) 'category': category,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (assignedEmails != null && assignedEmails.isNotEmpty)
        'assigned_emails': assignedEmails,
    });
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.files,
      data: form,
    );
    return CustomerFile.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Gmail Intake ─────────────────────────────────────────────────────────

  Future<(List<GmailIntakeItem>, Map<String, int>)> getGmailIntakeItems({
    String? search,
    String? status,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.gmailIntake,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'per_page': '200',
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => GmailIntakeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final statsJson = data['stats'] as Map<String, dynamic>? ?? {};
    final stats = statsJson.map(
      (k, v) => MapEntry(k, int.tryParse(v?.toString() ?? '0') ?? 0),
    );
    return (items, stats);
  }

  Future<GmailIntakePreview> getGmailIntakePreview(int id) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.gmailIntakePreview(id),
    );
    return GmailIntakePreview.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> resolveGmailIntakeItem(
    int id, {
    String? stripeCustomerId,
  }) async {
    await ApiClient.instance.dio.post(
      '${ApiEndpoints.gmailIntakeItem(id)}/resolve',
      data: {'stripe_customer_id': stripeCustomerId ?? ''},
    );
  }

  /// Files the message's attachments onto a customer's file record.
  Future<void> fileGmailIntakeItem(
    int id, {
    required String stripeCustomerId,
    String? tag,
    List<String>? attachmentIds,
    bool notify = false,
  }) async {
    await ApiClient.instance.dio.post(
      ApiEndpoints.gmailIntakeFile(id),
      data: {
        'stripe_customer_id': stripeCustomerId,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (attachmentIds != null) 'attachments': attachmentIds,
        'notify': notify,
      },
    );
  }

  Future<void> processGmailIntakeNow() async {
    await ApiClient.instance.dio.post('${ApiEndpoints.gmailIntake}/process');
  }

  // ── Sync ─────────────────────────────────────────────────────────────────
  // Fire-and-forget: AJCore schedules a one-off WP-Cron run and returns a
  // run_key immediately, same as the "⚡ Full Sync Now" button on AJOps web —
  // caller polls getSyncRunStatus() until done.

  /// jobs empty/omitted = full sync of every configured job (Stripe products,
  /// customers, subscriptions, invoices).
  Future<String> triggerSync({List<String> jobs = const []}) async {
    final resp = await ApiClient.instance.dio.post(
      ApiEndpoints.sync,
      data: {'jobs': jobs},
    );
    return (resp.data as Map<String, dynamic>)['run_key'] as String? ?? '';
  }

  /// Returns done/started/records_synced/errors for the given run.
  Future<Map<String, dynamic>> getSyncRunStatus(String runKey) async {
    final resp = await ApiClient.instance.dio.get(
      ApiEndpoints.syncRunStatus,
      queryParameters: {'run_key': runKey},
    );
    return resp.data as Map<String, dynamic>;
  }
}
