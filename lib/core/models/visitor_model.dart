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
    required this.linkedStripeCustomerId,
    required this.linkedCustomerName,
    required this.linkedLeadId,
    required this.linkedLeadName,
  });

  bool get isLinked => linkedCustomerName.isNotEmpty || linkedLeadName.isNotEmpty;

  // Same "possibly the same person" heuristic AJOps web clusters by — display-only, never treated
  // as identity (shared WiFi/VPN/carrier NAT all cause false matches).
  String get clusterKey => '$ipAddress|$browser|$os';

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
      linkedStripeCustomerId: json['linked_stripe_customer_id'] as String? ?? '',
      linkedCustomerName: json['linked_customer_name'] as String? ?? '',
      linkedLeadId: (json['linked_lead_id'] as num?)?.toInt() ?? 0,
      linkedLeadName: json['linked_lead_name'] as String? ?? '',
    );
  }
}
