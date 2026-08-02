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
  static String serviceRequestQuickAction(int id) => '/ops/service-requests/$id/quick-action';
  static String serviceRequestHistory(int id) => '/ops/service-requests/$id/history';
  static const String serviceRequestsBulk = '/ops/service-requests/bulk';

  // ── Live Chat ───────────────────────────────────────────────────────────
  static const String chatSessions = '/ops/chat/sessions';
  static String chatSessionMessages(int id) => '/ops/chat/sessions/$id/messages';
  static String chatSessionReply(int id) => '/ops/chat/sessions/$id/reply';
  static String chatSessionClaim(int id) => '/ops/chat/sessions/$id/claim';
  static String chatSessionUnclaim(int id) => '/ops/chat/sessions/$id/unclaim';
  static String chatSessionClose(int id) => '/ops/chat/sessions/$id/close';

  // ── UPOS Temps (Resideo thermostats) ────────────────────────────────────
  // Bulk (all configured devices) and per-device are separate route sets on
  // AJCore, not one endpoint with an optional deviceId.
  static const String uposTemps = '/ops/upos-temps';
  static const String uposTempsSystemBulk = '/ops/upos-temps/system';
  static const String uposTempsFanBulk = '/ops/upos-temps/fan';
  static String uposTempsDeviceSystem(String deviceId) => '/ops/upos-temps/devices/$deviceId/system';
  static String uposTempsDeviceFan(String deviceId) => '/ops/upos-temps/devices/$deviceId/fan';
}
