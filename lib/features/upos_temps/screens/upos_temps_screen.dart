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
  bool _pickerOpen = false;
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
    final visible = state.visibleDevices;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredDevices = normalizedQuery.isEmpty
        ? visible
        : visible
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
                  if (state.locationIds.length > 1) ...[
                    _LocationsCard(
                      locationIds: state.locationIds,
                      selectedLocationIds: state.selectedLocationIds ?? {},
                      onToggleLocation: notifier.toggleLocationSelected,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _BulkControlCard(
                    busy:
                        state.busyDeviceKeys.contains('-system') ||
                        state.busyDeviceKeys.contains('-fan'),
                    notifier: notifier,
                    runBulk: _runBulk,
                  ),
                  const SizedBox(height: 10),
                  _PickerCard(
                    devices: state.devices,
                    selectedIds: state.selectedIds ?? {},
                    open: _pickerOpen,
                    onToggleOpen: () =>
                        setState(() => _pickerOpen = !_pickerOpen),
                    onToggleDevice: notifier.toggleSelected,
                    onSelectAll: notifier.selectAll,
                    onClear: notifier.clearSelection,
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
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No thermostats selected. Use "Select thermostats" above.',
                        style: TextStyle(color: Colors.grey.shade600),
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
                          busy:
                              state.busyDeviceKeys.contains('${d.id}-system') ||
                              state.busyDeviceKeys.contains('${d.id}-fan'),
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
  final UposTempsNotifier notifier;
  final Future<void> Function(Future<String?> Function()) runBulk;

  const _BulkControlCard({
    required this.busy,
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All thermostats',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Send one system or fan mode to every configured thermostat.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
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
              disabled: busy,
              onSelect: (m) => runBulk(() => notifier.setSystemMode(m)),
            ),
            const SizedBox(height: 10),
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
              disabled: busy,
              onSelect: (m) => runBulk(() => notifier.setFanMode(m)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationsCard extends StatelessWidget {
  final List<String> locationIds;
  final Set<String> selectedLocationIds;
  final void Function(String) onToggleLocation;

  const _LocationsCard({
    required this.locationIds,
    required this.selectedLocationIds,
    required this.onToggleLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Locations',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Both are selected by default — uncheck to hide a location\'s thermostats below.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            ...locationIds.asMap().entries.map(
              (entry) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selectedLocationIds.contains(entry.value),
                onChanged: (_) => onToggleLocation(entry.value),
                title: Text('Location ${entry.key + 1}'),
                subtitle: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final List<UposDevice> devices;
  final Set<String> selectedIds;
  final bool open;
  final VoidCallback onToggleOpen;
  final void Function(String) onToggleDevice;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  const _PickerCard({
    required this.devices,
    required this.selectedIds,
    required this.open,
    required this.onToggleOpen,
    required this.onToggleDevice,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thermostats to show',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${selectedIds.length} of ${devices.length} shown below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggleOpen,
                  child: Text(open ? 'Done' : 'Select thermostats'),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: onSelectAll,
                    child: const Text('Select all'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...devices.map(
                (d) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selectedIds.contains(d.id),
                  onChanged: (_) => onToggleDevice(d.id),
                  title: Text(d.name),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final UposDevice device;
  final bool busy;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.busy,
    required this.onTap,
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
