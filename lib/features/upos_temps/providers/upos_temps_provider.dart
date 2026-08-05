import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/upos_device_model.dart';
import '../../../core/utils/error_utils.dart';

// Which thermostats/locations to display are per-device display preferences, not shared ops
// data — kept locally rather than round-tripped through AJCore/settings, same call as the AJOps
// web version.
const _selectedIdsPrefsKey = 'upos_temps_selected_device_ids';
const _selectedLocationIdsPrefsKey = 'upos_temps_selected_location_ids';

class UposTempsState {
  final List<UposDevice> devices;
  final bool ready; // Resideo connection configured on AJCore
  final bool loading;
  final String? error;
  final Set<String>? selectedIds; // null = not yet loaded from prefs
  final Set<String>? selectedLocationIds; // null = not yet loaded from prefs
  final Set<String> busyDeviceKeys; // "<deviceId>-<action>", "" for bulk

  const UposTempsState({
    this.devices = const [],
    this.ready = false,
    this.loading = true,
    this.error,
    this.selectedIds,
    this.selectedLocationIds,
    this.busyDeviceKeys = const {},
  });

  UposTempsState copyWith({
    List<UposDevice>? devices,
    bool? ready,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<String>? selectedIds,
    Set<String>? selectedLocationIds,
    Set<String>? busyDeviceKeys,
  }) {
    return UposTempsState(
      devices: devices ?? this.devices,
      ready: ready ?? this.ready,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      selectedLocationIds: selectedLocationIds ?? this.selectedLocationIds,
      busyDeviceKeys: busyDeviceKeys ?? this.busyDeviceKeys,
    );
  }

  /// Unique location IDs across the fetched devices, in a stable (sorted) order.
  List<String> get locationIds =>
      devices.map((d) => d.locationId).toSet().toList()..sort();

  Map<String, String> get locationNames => {
    for (final device in devices)
      device.locationId: device.locationName.isNotEmpty
          ? device.locationName
          : device.locationId,
  };

  List<UposDevice> get selectedDevices {
    if (selectedIds == null) return const [];
    return devices.where((d) => selectedIds!.contains(d.id)).toList();
  }

  List<UposDevice> get locationFilteredDevices {
    if (selectedLocationIds == null) return const [];
    return devices
        .where((d) => selectedLocationIds!.contains(d.locationId))
        .toList();
  }
}

class UposTempsNotifier extends StateNotifier<UposTempsState> {
  UposTempsNotifier() : super(const UposTempsState()) {
    _loadPrefs();
    load();
  }

  final _api = OpsApi.instance;

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds = prefs.getStringList(_selectedIdsPrefsKey);
    final storedLocationIds = prefs.getStringList(_selectedLocationIdsPrefsKey);
    state = state.copyWith(
      selectedIds: storedIds != null
          ? storedIds.toSet()
          : (state.devices.isNotEmpty
                ? state.devices.map((d) => d.id).toSet()
                : null),
      selectedLocationIds: storedLocationIds != null
          ? storedLocationIds.toSet()
          : (state.devices.isNotEmpty ? state.locationIds.toSet() : null),
    );
  }

  Future<void> _persistSelectedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _selectedIdsPrefsKey,
      state.selectedIds?.toList() ?? [],
    );
  }

  Future<void> _persistSelectedLocationIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _selectedLocationIdsPrefsKey,
      state.selectedLocationIds?.toList() ?? [],
    );
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (loadedDevices, settings) = await _api.getUposTemps();
      final devices = [...loadedDevices]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      // First-ever load (no saved preference yet, prefs already checked in _loadPrefs): default
      // to showing everything — all devices, both/all locations — rather than an empty grid.
      final selectedIds = state.selectedIds ?? devices.map((d) => d.id).toSet();
      final knownLocationIds = devices.map((d) => d.locationId).toSet();
      final selectedLocationIds = state.selectedLocationIds ?? knownLocationIds;
      state = state.copyWith(
        devices: devices,
        ready: settings.ready,
        loading: false,
        clearError: true,
        selectedIds: selectedIds,
        selectedLocationIds: selectedLocationIds,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void toggleSelected(String deviceId) {
    final current = state.selectedIds ?? {};
    final next = {...current};
    if (!next.add(deviceId)) next.remove(deviceId);
    state = state.copyWith(selectedIds: next);
    _persistSelectedIds();
  }

  void selectAll() {
    state = state.copyWith(selectedIds: state.devices.map((d) => d.id).toSet());
    _persistSelectedIds();
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
    _persistSelectedIds();
  }

  void toggleLocationSelected(String locationId) {
    final current = state.selectedLocationIds ?? {};
    final next = {...current};
    if (!next.add(locationId)) next.remove(locationId);
    state = state.copyWith(selectedLocationIds: next);
    _persistSelectedLocationIds();
  }

  Future<String?> setSystemMode(
    String mode, {
    String? deviceId,
    List<String>? deviceIds,
  }) => _runControl(
    key: '${deviceId ?? ""}-system',
    action: () =>
        _api.setUposSystemMode(mode, deviceId: deviceId, deviceIds: deviceIds),
  );

  Future<String?> setFanMode(
    String mode, {
    String? deviceId,
    List<String>? deviceIds,
  }) => _runControl(
    key: '${deviceId ?? ""}-fan',
    action: () =>
        _api.setUposFanMode(mode, deviceId: deviceId, deviceIds: deviceIds),
  );

  Future<String?> _runControl({
    required String key,
    required Future<void> Function() action,
  }) async {
    state = state.copyWith(busyDeviceKeys: {...state.busyDeviceKeys, key});
    try {
      await action();
      state = state.copyWith(
        busyDeviceKeys: {...state.busyDeviceKeys}..remove(key),
      );
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(
        busyDeviceKeys: {...state.busyDeviceKeys}..remove(key),
      );
      return friendlyError(e);
    }
  }
}

final uposTempsProvider =
    StateNotifierProvider.autoDispose<UposTempsNotifier, UposTempsState>(
      (ref) => UposTempsNotifier(),
    );
