/// All AJ Core OPS REST API endpoint paths relative to apiBaseUrl.
/// These are the same `/ops/*` routes AJOps (the Next.js web app) uses —
/// see class-ajcore-rest-api.php. Only staff (Admin / ajcore_ops_access /
/// aj_ops_user role) can authenticate against them.
class ApiEndpoints {
  ApiEndpoints._();

  // ── System ──────────────────────────────────────────────────────────────
  static const String status = '/status';

  static const String features = '/ops/features';
  static const String hoaViolationTypes = '/ops/hoa/violation-types';
  static const String hoaAddressViolations = '/ops/hoa/address-violations';
  static const String hoaInspections = '/ops/hoa/inspections';
  static const String counts = '/ops/counts';
  static const String hoaCommunities = '/ops/hoa/communities';
  static String hoaCommunity(String id) => '/ops/hoa/communities/${Uri.encodeComponent(id)}';
  static String hoaUnit(int id) => '/ops/hoa/units/$id';

  // ── Auth ────────────────────────────────────────────────────────────────
  static const String login = '/ops/auth/login';
  static const String logout = '/ops/auth/logout';
  static const String me = '/ops/auth/me';

  // ── Dashboard ───────────────────────────────────────────────────────────
  static const String summary = '/ops/summary';

  // ── Staff (for assignee dropdown) ──────────────────────────────────────
  static const String staff = '/ops/staff';

  // ── Service Requests ────────────────────────────────────────────────────
  static const String serviceRequests = '/ops/requests';
  static String updateServiceRequest(int id) => '/ops/requests/$id';
  static String serviceRequestQuickAction(int id) =>
      '/ops/requests/$id/quick-action';
  static String serviceRequestNotify(int id) =>
      '/ops/requests/$id/notify';
  static String serviceRequestHistory(int id) =>
      '/ops/requests/$id/history';
  static const String serviceRequestsBulk = '/ops/requests/bulk';

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

  // ── Leads ────────────────────────────────────────────────────────────────
  static const String leads = '/ops/leads';
  static String lead(int id) => '/ops/leads/$id';
  static String leadNotes(int id) => '/ops/leads/$id/notes';
  static String leadPipelineStatus(int id) => '/ops/leads/$id/pipeline-status';
  static const String leadsBulk = '/ops/leads/bulk';

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

  // ── Pipeline ─────────────────────────────────────────────────────────
  static const String pipeline = '/ops/gmail-intake';
  static String pipelineItem(int id) => '/ops/gmail-intake/$id';
  static String pipelinePreview(int id) => '/ops/gmail-intake/$id/preview';
  static String pipelineFile(int id) => '/ops/gmail-intake/$id/file';
  static const String pipelineReset = '/ops/gmail-intake/reset';
  static String pipelineMarkFiled(int id) => '/ops/gmail-intake/$id/mark-filed';

  // ── Pipeline > Purchases (AJCore-RA) ─────────────────────────────────
  static const String purchases = '/ops/purchases';
  static String purchase(int id) => '/ops/purchases/$id';
  static const String purchasesStage = '/ops/purchases/stage';
  static const String purchasesProcess = '/ops/purchases/process';

  // ── Sync (Stripe products/customers/subscriptions/invoices) ───────────────
  static const String sync = '/ops/sync';
  static const String syncRunStatus = '/ops/sync/run-status';
  static const String syncStatus = '/ops/sync/status';

  // ── Email Log ────────────────────────────────────────────────────────────
  static const String emailLog = '/ops/email-log';
  static String emailLogEntry(int id) => '/ops/email-log/$id';

  // ── Settings: staff + reception (front desk iPad keys) ───────────────────
  static String staffMember(int id) => '/ops/staff/$id';
  static String staffProfile(int id) => '/ops/staff/$id/profile';
  static String staffPermissions(int id) => '/ops/staff/$id/permissions';
  static const String receptionDevices = '/ops/reception/devices';
  static String receptionDeviceRevoke(String id) => '/ops/reception/devices/$id/revoke';
}
