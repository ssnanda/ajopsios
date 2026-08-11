class ApiStatusModel {
  final bool reachable;
  final String version;
  final String siteUuid;
  final bool multiSiteEnabled;
  final bool masterApiOk;
  final String? message;
  // AJCore's configured business timezone (Settings > General on the WP site) — the source of
  // truth every screen in this app should display times in, rather than the device's own local
  // zone, so a traveling staff member sees the same wall-clock time for an event as everyone else.
  // See class-ajcore-rest-api.php's get_status() for why there are two forms: `timezone` is an
  // IANA name ("America/New_York") for anything that can do real zone conversion, `utcOffsetSeconds`
  // is a plain right-now offset for callers (this app) without a tzdata engine handy. Both are only
  // valid for "now" — re-fetch status rather than caching this indefinitely across a DST boundary.
  final String timezone;
  final String timezoneAbbr;
  final int utcOffsetSeconds;

  const ApiStatusModel({
    required this.reachable,
    required this.version,
    required this.siteUuid,
    required this.multiSiteEnabled,
    required this.masterApiOk,
    this.message,
    this.timezone = 'UTC',
    this.timezoneAbbr = 'UTC',
    this.utcOffsetSeconds = 0,
  });

  factory ApiStatusModel.fromJson(Map<String, dynamic> json) {
    return ApiStatusModel(
      reachable: true,
      version: json['version'] as String? ?? '',
      siteUuid: json['site_uuid'] as String? ?? '',
      multiSiteEnabled: json['multisite_enabled'] as bool? ?? false,
      masterApiOk: json['master_api_ok'] as bool? ?? false,
      message: json['message'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      timezoneAbbr: json['timezone_abbr'] as String? ?? 'UTC',
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  static ApiStatusModel unreachable(String reason) => ApiStatusModel(
        reachable: false,
        version: '',
        siteUuid: '',
        multiSiteEnabled: false,
        masterApiOk: false,
        message: reason,
      );
}
