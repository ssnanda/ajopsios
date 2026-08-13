/// GET /ops/visitors row shape (get_ops_visitor_history in class-ajcore-rest-api.php) — one row
/// per unique browser (visitor_uuid), whether currently online (isOnline, ended_at IS NULL on
/// their latest AJCore visit row) or a past visit. Same source AJOps web's Visitor History and
/// Live Monitor both read, just filtered differently (see OpsApi.getVisitors online param).
class Visitor {
  final String visitorUuid;
  final String siteUuid;
  final String ipAddress;
  final String country;
  final String region;
  final String city;
  final String browser;
  final String os;
  final String deviceType;
  final String lastPage;
  final int visits;
  final String firstSeen;
  final String lastSeen;
  final bool isOnline;
  // Cumulative across every visit (including how long a still-online visit has run so far) — the
  // "visit timer" keeps climbing on a repeat visit rather than resetting to 0 each time. AJOps web
  // reads it the same way (see get_ops_visitor_history() in class-ajcore-rest-api.php).
  final int totalSeconds;
  final String linkedStripeCustomerId;
  final String linkedCustomerName;
  final int linkedLeadId;
  final String linkedLeadName;

  const Visitor({
    required this.visitorUuid,
    required this.siteUuid,
    required this.ipAddress,
    required this.country,
    required this.region,
    required this.city,
    required this.browser,
    required this.os,
    required this.deviceType,
    required this.lastPage,
    required this.visits,
    required this.firstSeen,
    required this.lastSeen,
    required this.isOnline,
    required this.totalSeconds,
    required this.linkedStripeCustomerId,
    required this.linkedCustomerName,
    required this.linkedLeadId,
    required this.linkedLeadName,
  });

  bool get isLinked => linkedCustomerName.isNotEmpty || linkedLeadName.isNotEmpty;

  // Same "possibly the same person" heuristic AJOps web clusters by — display-only, never treated
  // as identity (shared WiFi/VPN/carrier NAT all cause false matches). browser/os are "name +
  // version" (e.g. "Mobile Safari 17.4.1") — strip the trailing version token so an iOS/browser
  // point update between visits doesn't fragment the same phone into separate clusters.
  String get clusterKey =>
      '$ipAddress|${_stripVersion(browser)}|${_stripVersion(os)}';

  static String _stripVersion(String s) => s.replaceAll(RegExp(r'\s+\d[\d.]*$'), '');

  String get location => [city, region, country].where((s) => s.isNotEmpty).join(', ');

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      visitorUuid: json['visitor_uuid'] as String? ?? '',
      siteUuid: json['site_uuid'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      country: json['country'] as String? ?? '',
      region: json['region'] as String? ?? '',
      city: json['city'] as String? ?? '',
      browser: json['browser'] as String? ?? '',
      os: json['os'] as String? ?? '',
      deviceType: json['device_type'] as String? ?? '',
      lastPage: json['last_page'] as String? ?? '',
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      firstSeen: json['first_seen'] as String? ?? '',
      lastSeen: json['last_seen'] as String? ?? '',
      isOnline: json['is_online'] == true,
      totalSeconds: (json['total_seconds'] as num?)?.toInt() ?? 0,
      linkedStripeCustomerId: json['linked_stripe_customer_id'] as String? ?? '',
      linkedCustomerName: json['linked_customer_name'] as String? ?? '',
      linkedLeadId: (json['linked_lead_id'] as num?)?.toInt() ?? 0,
      linkedLeadName: json['linked_lead_name'] as String? ?? '',
    );
  }
}

/// "2h 14m" / "9m" / "42s" — used for Visitor.totalSeconds on both Visitor History (static, as of
/// last load) and Live Monitor (ticks locally between polls for a currently-online visitor; see
/// LiveMonitorScreen). A near-instant visit (page loaded and closed within the same second) makes
/// AJCore's TIMESTAMPDIFF(SECOND, started_at, ended_at) come back as a genuine 0 — mathematically
/// correct, but "0s" reads as broken/no-data to someone looking at a visitor who very clearly did
/// show up, so this floors display at 1s rather than showing that literal 0.
String formatVisitDuration(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds <= 0 ? 1 : totalSeconds}s';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
