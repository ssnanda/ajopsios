/// All AJ Core OPS REST API endpoint paths relative to apiBaseUrl.
/// These are the same `/ops/*` routes AJOps (the Next.js web app) uses —
/// see class-ajcore-rest-api.php. Only staff (Admin / ajcore_ops_access /
/// aj_ops_user role) can authenticate against them.
class ApiEndpoints {
  ApiEndpoints._();

  // ── System ──────────────────────────────────────────────────────────────
  static const String status = '/status';

  // ── Auth ────────────────────────────────────────────────────────────────
  static const String login = '/ops/auth/login';
  static const String logout = '/ops/auth/logout';
  static const String me = '/ops/auth/me';

  // ── Dashboard ───────────────────────────────────────────────────────────
  static const String summary = '/ops/summary';

  // ── Staff (for assignee dropdown) ──────────────────────────────────────
  static const String staff = '/ops/staff';

  // ── Service Requests ────────────────────────────────────────────────────
  static const String serviceRequests = '/ops/service-requests';
  static String updateServiceRequest(int id) => '/ops/service-requests/$id';
  static String serviceRequestQuickAction(int id) =>
      '/ops/service-requests/$id/quick-action';
  static String serviceRequestNotify(int id) =>
      '/ops/service-requests/$id/notify';
  static String serviceRequestHistory(int id) =>
      '/ops/service-requests/$id/history';
  static const String serviceRequestsBulk = '/ops/service-requests/bulk';

  // ── Live Chat ───────────────────────────────────────────────────────────
  static const String chatSessions = '/ops/chat/sessions';
  static String chatSessionMessages(int id) =>
      '/ops/chat/sessions/$id/messages';
  static String chatSessionReply(int id) => '/ops/chat/sessions/$id/reply';
  static String chatSessionClaim(int id) => '/ops/chat/sessions/$id/claim';
  static String chatSessionUnclaim(int id) => '/ops/chat/sessions/$id/unclaim';
  static String chatSessionClose(int id) => '/ops/chat/sessions/$id/close';

  // ── Visitor History / Live Monitor ──────────────────────────────────────
  static const String visitors = '/ops/visitors';
  static String visitorLink(String visitorUuid) =>
      '/ops/visitors/${Uri.encodeComponent(visitorUuid)}/link';
  static String visitorUnlink(String visitorUuid) =>
      '/ops/visitors/${Uri.encodeComponent(visitorUuid)}/unlink';

  // ── UPOS Temps (Resideo thermostats) ────────────────────────────────────
  // Bulk (all configured devices) and per-device are separate route sets on
  // AJCore, not one endpoint with an optional deviceId.
  static const String uposTemps = '/ops/upos-temps';
  static const String uposTempsSystemBulk = '/ops/upos-temps/system';
  static const String uposTempsFanBulk = '/ops/upos-temps/fan';
  static String uposTempsDeviceSystem(String deviceId) =>
      '/ops/upos-temps/devices/$deviceId/system';
  static String uposTempsDeviceFan(String deviceId) =>
      '/ops/upos-temps/devices/$deviceId/fan';

  // ── Leads ────────────────────────────────────────────────────────────────
  static const String leads = '/ops/leads';
  static String lead(int id) => '/ops/leads/$id';
  static String leadNotes(int id) => '/ops/leads/$id/notes';
  static String leadPipelineStatus(int id) => '/ops/leads/$id/pipeline-status';

  // ── Connected sites (site picker on the lead edit form) ────────────────────
  static const String sites = '/ops/sites';

  // ── Customers ────────────────────────────────────────────────────────────
  static const String customers = '/ops/customers';
  static String customer(String stripeCustomerId) =>
      '/ops/customers/$stripeCustomerId';
  static String customerAction(String stripeCustomerId) =>
      '/ops/customers/$stripeCustomerId/action';

  // ── Mail ─────────────────────────────────────────────────────────────────
  static const String mail = '/ops/mail';
  static String mailItem(int id) => '/ops/mail/$id';

  // ── Files ────────────────────────────────────────────────────────────────
  static const String files = '/ops/files';
  static String file(int id) => '/ops/files/$id';

  // ── Gmail Intake ─────────────────────────────────────────────────────────
  static const String gmailIntake = '/ops/gmail-intake';
  static String gmailIntakeItem(int id) => '/ops/gmail-intake/$id';
  static String gmailIntakePreview(int id) => '/ops/gmail-intake/$id/preview';
  static String gmailIntakeFile(int id) => '/ops/gmail-intake/$id/file';

  // ── Sync (Stripe products/customers/subscriptions/invoices) ───────────────
  static const String sync = '/ops/sync';
  static const String syncRunStatus = '/ops/sync/run-status';
  static const String syncStatus = '/ops/sync/status';
}
