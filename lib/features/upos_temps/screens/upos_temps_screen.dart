import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/upos_device_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/upos_temps_provider.dart';
import '../widgets/compact_mode_row.dart';
import '../widgets/thermostat_detail_sheet.dart';

class UposTempsScreen extends ConsumerStatefulWidget {
  const UposTempsScreen({super.key});

  @override
  ConsumerState<UposTempsScreen> createState() => _UposTempsScreenState();
}

class _UposTempsScreenState extends ConsumerState<UposTempsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runBulk(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uposTempsProvider);
    final notifier = ref.read(uposTempsProvider.notifier);
    final selected = state.selectedDevices;
    final locationFiltered = state.locationFilteredDevices;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredDevices = normalizedQuery.isEmpty
        ? locationFiltered
        : locationFiltered
              .where(
                (device) =>
                    device.name.toLowerCase().contains(normalizedQuery) ||
                    device.id.toLowerCase().contains(normalizedQuery),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPOS Temps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.load,
          ),
        ],
      ),
      body: state.loading
          ? const AjLoadingIndicator()
          : state.error != null
          ? ErrorState(message: state.error!, onRetry: notifier.load)
          : !state.ready
          ? const EmptyState(
              icon: Icons.thermostat_outlined,
              title: 'Resideo not configured',
              subtitle:
                  'Configure the UPOS Resideo connection in AJOps settings first.',
            )
          : RefreshIndicator(
              onRefresh: notifier.load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search thermostats',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 10),
                  _BulkControlCard(
                    busy:
                        state.busyDeviceKeys.contains('-system') ||
                        state.busyDeviceKeys.contains('-fan'),
                    deviceIds: selected.map((device) => device.id).toList(),
                    selectedCount: selected.length,
                    locationIds: state.locationIds,
                    locationNames: state.locationNames,
                    selectedLocationIds: state.selectedLocationIds ?? {},
                    onToggleLocation: notifier.toggleLocationSelected,
                    onSelectAll: notifier.selectAll,
                    onSelectNone: notifier.clearSelection,
                    notifier: notifier,
                    runBulk: _runBulk,
                  ),
                  const SizedBox(height: 10),
                  if (state.devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.thermostat_outlined,
                        title: 'No devices loaded',
                        subtitle: 'Pull to refresh to query Resideo.',
                      ),
                    )
                  else if (filteredDevices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No thermostats match "${_searchQuery.trim()}".',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ...filteredDevices.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DeviceCard(
                          device: d,
                          selected: state.selectedIds?.contains(d.id) ?? false,
                          busy:
                              state.busyDeviceKeys.contains('${d.id}-system') ||
                              state.busyDeviceKeys.contains('${d.id}-fan'),
                          onToggleSelected: () => notifier.toggleSelected(d.id),
                          onTap: () => showThermostatDetailSheet(
                            context,
                            device: d,
                            busy:
                                state.busyDeviceKeys.contains(
                                  '${d.id}-system',
                                ) ||
                                state.busyDeviceKeys.contains('${d.id}-fan'),
                            onSystemChange: (mode) =>
                                notifier.setSystemMode(mode, deviceId: d.id),
                            onFanChange: (mode) =>
                                notifier.setFanMode(mode, deviceId: d.id),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BulkControlCard extends StatelessWidget {
  final bool busy;
  final List<String> deviceIds;
  final int selectedCount;
  final List<String> locationIds;
  final Map<String, String> locationNames;
  final Set<String> selectedLocationIds;
  final void Function(String) onToggleLocation;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectNone;
  final UposTempsNotifier notifier;
  final Future<void> Function(Future<String?> Function()) runBulk;

  const _BulkControlCard({
    required this.busy,
    required this.deviceIds,
    required this.selectedCount,
    required this.locationIds,
    required this.locationNames,
    required this.selectedLocationIds,
    required this.onToggleLocation,
    required this.onSelectAll,
    required this.onSelectNone,
    required this.notifier,
    required this.runBulk,
  });

  static const _systemModes = ['Off', 'Cool', 'Heat', 'Auto'];
  static const _fanModes = ['On', 'Auto', 'Circulate'];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locationIds.length > 1) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: locationIds
                    .map(
                      (id) => FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(locationNames[id] ?? id),
                        selected: selectedLocationIds.contains(id),
                        onSelected: (_) => onToggleLocation(id),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(
                  '$selectedCount selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSelectAll,
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: onSelectNone,
                  child: const Text('Select none'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'SYSTEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            CompactModeRow(
              modes: _systemModes,
              disabled: busy || deviceIds.isEmpty,
              onSelect: (m) => runBulk(
                () => notifier.setSystemMode(m, deviceIds: deviceIds),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            CompactModeRow(
              modes: _fanModes,
              disabled: busy || deviceIds.isEmpty,
              onSelect: (m) =>
                  runBulk(() => notifier.setFanMode(m, deviceIds: deviceIds)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final UposDevice device;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggleSelected;

  const _DeviceCard({
    required this.device,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggleSelected()),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          label: 'Indoor ${_formatTemp(device.indoorTemp)}',
                        ),
                        _Chip(label: 'Set ${_formatTemp(device.setTemp)}'),
                        _Chip(label: device.mode ?? '—'),
                        _Chip(label: 'Fan ${device.fanMode ?? '—'}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _formatTemp(double? value) => value == null ? '—' : '${value.round()}°F';
