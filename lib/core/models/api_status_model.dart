class ApiStatusModel {
  final bool reachable;
  final String version;
  final String siteUuid;
  final bool multiSiteEnabled;
  final bool masterApiOk;
  final String? message;

  const ApiStatusModel({
    required this.reachable,
    required this.version,
    required this.siteUuid,
    required this.multiSiteEnabled,
    required this.masterApiOk,
    this.message,
  });

  factory ApiStatusModel.fromJson(Map<String, dynamic> json) {
    return ApiStatusModel(
      reachable: true,
      version: json['version'] as String? ?? '',
      siteUuid: json['site_uuid'] as String? ?? '',
      multiSiteEnabled: json['multisite_enabled'] as bool? ?? false,
      masterApiOk: json['master_api_ok'] as bool? ?? false,
      message: json['message'] as String?,
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
