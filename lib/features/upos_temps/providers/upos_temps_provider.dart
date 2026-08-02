import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/upos_device_model.dart';
import '../../../core/utils/error_utils.dart';

// Which thermostats to display is a per-device display preference, not shared ops data — kept
// locally rather than round-tripped through AJCore/settings, same call as the AJOps web version.
const _selectedIdsPrefsKey = 'upos_temps_selected_device_ids';

class UposTempsState {
  final List<UposDevice> devices;
  final bool ready; // Resideo connection configured on AJCore
  final bool loading;
  final String? error;
  final Set<String>? selectedIds; // null = not yet loaded from prefs
  final Set<String> busyDeviceKeys; // "<deviceId>-<action>", "" for bulk

  const UposTempsState({
    this.devices = const [],
    this.ready = false,
    this.loading = true,
    this.error,
    this.selectedIds,
    this.busyDeviceKeys = const {},
  });

  UposTempsState copyWith({
    List<UposDevice>? devices,
    bool? ready,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<String>? selectedIds,
    Set<String>? busyDeviceKeys,
  }) {
    return UposTempsState(
      devices: devices ?? this.devices,
      ready: ready ?? this.ready,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      busyDeviceKeys: busyDeviceKeys ?? this.busyDeviceKeys,
    );
  }

  List<UposDevice> get visibleDevices =>
      selectedIds == null ? const [] : devices.where((d) => selectedIds!.contains(d.id)).toList();
}

class UposTempsNotifier extends StateNotifier<UposTempsState> {
  UposTempsNotifier() : super(const UposTempsState()) {
    _loadSelectedIds();
    load();
  }

  final _api = OpsApi.instance;

  Future<void> _loadSelectedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_selectedIdsPrefsKey);
    if (stored != null) {
      state = state.copyWith(selectedIds: stored.toSet());
    } else if (state.devices.isNotEmpty) {
      // First-ever load with devices already in: default to showing everything.
      state = state.copyWith(selectedIds: state.devices.map((d) => d.id).toSet());
    }
  }

  Future<void> _persistSelectedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefsKey, state.selectedIds?.toList() ?? []);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (devices, settings) = await _api.getUposTemps();
      // First-ever load (no saved preference yet, prefs already checked in _loadSelectedIds):
      // default to showing everything rather than an empty grid.
      final selectedIds = state.selectedIds ?? devices.map((d) => d.id).toSet();
      state = state.copyWith(devices: devices, ready: settings.ready, loading: false, clearError: true, selectedIds: selectedIds);
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

  Future<String?> setSystemMode(String mode, {String? deviceId}) =>
      _runControl(key: '${deviceId ?? ""}-system', action: () => _api.setUposSystemMode(mode, deviceId: deviceId));

  Future<String?> setFanMode(String mode, {String? deviceId}) =>
      _runControl(key: '${deviceId ?? ""}-fan', action: () => _api.setUposFanMode(mode, deviceId: deviceId));

  Future<String?> _runControl({required String key, required Future<void> Function() action}) async {
    state = state.copyWith(busyDeviceKeys: {...state.busyDeviceKeys, key});
    try {
      await action();
      state = state.copyWith(busyDeviceKeys: {...state.busyDeviceKeys}..remove(key));
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(busyDeviceKeys: {...state.busyDeviceKeys}..remove(key));
      return friendlyError(e);
    }
  }
}

final uposTempsProvider = StateNotifierProvider.autoDispose<UposTempsNotifier, UposTempsState>(
  (ref) => UposTempsNotifier(),
);
