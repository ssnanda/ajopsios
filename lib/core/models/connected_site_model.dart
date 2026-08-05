/// One row of the shared-DB control table (aj_shared_sites) — every WordPress
/// site sharing this portal's leads/customers/Stripe data. Mirrors AJOps web's
/// ConnectedSite (ajops/src/lib/ajcore/types.ts) and GET /ops/sites.
class ConnectedSite {
  final String siteUuid;
  final String domain;
  final bool isMaster;

  const ConnectedSite({
    required this.siteUuid,
    required this.domain,
    required this.isMaster,
  });

  factory ConnectedSite.fromJson(Map<String, dynamic> json) => ConnectedSite(
    siteUuid: json['site_uuid'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
    isMaster: json['is_master'] as bool? ?? false,
  );

  String get label => domain.isNotEmpty
      ? domain
      : (siteUuid.length > 8 ? siteUuid.substring(0, 8) : siteUuid);
}
