/// GET /ops/upos-temps device row shape — mirrors the same AJCore endpoint
/// AJOps' web client reads (see class-ajcore-upos-temps.php).
class UposDevice {
  final String id;
  final String name;
  final String locationId;
  final String locationName;
  final double? indoorTemp;
  final double? setTemp;
  final String? mode;
  final String? fanMode;
  final double? heatSetpoint;
  final double? coolSetpoint;
  final List<String> availableSystemModes;
  final List<String> availableFanModes;

  const UposDevice({
    required this.id,
    required this.name,
    required this.locationId,
    required this.locationName,
    required this.indoorTemp,
    required this.setTemp,
    required this.mode,
    required this.fanMode,
    required this.heatSetpoint,
    required this.coolSetpoint,
    required this.availableSystemModes,
    required this.availableFanModes,
  });

  factory UposDevice.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return UposDevice(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      locationId: json['location_id']?.toString() ?? '',
      locationName: json['location_name'] as String? ?? '',
      indoorTemp: (json['indoor_temp'] as num?)?.toDouble(),
      setTemp: (json['set_temp'] as num?)?.toDouble(),
      mode: json['mode'] as String?,
      fanMode: json['fan_mode'] as String?,
      heatSetpoint: (json['heat_setpoint'] as num?)?.toDouble(),
      coolSetpoint: (json['cool_setpoint'] as num?)?.toDouble(),
      availableSystemModes: asStringList(json['available_system_modes']),
      availableFanModes: asStringList(json['available_fan_modes']),
    );
  }
}

class UposSettingsStatus {
  final bool ready;
  final List<String> deviceIds;

  const UposSettingsStatus({required this.ready, required this.deviceIds});

  factory UposSettingsStatus.fromJson(Map<String, dynamic> json) {
    return UposSettingsStatus(
      ready: json['ready'] == true,
      deviceIds:
          (json['device_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  static const empty = UposSettingsStatus(ready: false, deviceIds: []);
}
