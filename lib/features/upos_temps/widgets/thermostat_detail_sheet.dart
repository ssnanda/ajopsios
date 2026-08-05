import 'package:flutter/material.dart';
import '../../../core/models/upos_device_model.dart';
import 'compact_mode_row.dart';

Future<void> showThermostatDetailSheet(
  BuildContext context, {
  required UposDevice device,
  required bool busy,
  required Future<String?> Function(String mode) onSystemChange,
  required Future<String?> Function(String mode) onFanChange,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _ThermostatDetailContent(
      device: device,
      busy: busy,
      onSystemChange: onSystemChange,
      onFanChange: onFanChange,
    ),
  );
}

class _ThermostatDetailContent extends StatelessWidget {
  final UposDevice device;
  final bool busy;
  final Future<String?> Function(String mode) onSystemChange;
  final Future<String?> Function(String mode) onFanChange;

  const _ThermostatDetailContent({
    required this.device,
    required this.busy,
    required this.onSystemChange,
    required this.onFanChange,
  });

  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final err = await action();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Device ${device.id}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _Metric(label: 'Indoor', value: _formatTemp(device.indoorTemp)),
                _Metric(label: 'Set', value: _formatTemp(device.setTemp)),
                _Metric(label: 'System', value: device.mode ?? '—'),
                _Metric(label: 'Fan', value: device.fanMode ?? '—'),
                _Metric(label: 'Heat setpoint', value: _formatTemp(device.heatSetpoint)),
                _Metric(label: 'Cool setpoint', value: _formatTemp(device.coolSetpoint)),
              ],
            ),
            const SizedBox(height: 20),
            _ControlGroup(
              label: 'System',
              modes: device.availableSystemModes,
              selected: device.mode,
              busy: busy,
              onSelect: (mode) => _run(context, () => onSystemChange(mode)),
            ),
            const SizedBox(height: 16),
            _ControlGroup(
              label: 'Fan',
              modes: device.availableFanModes,
              selected: device.fanMode,
              busy: busy,
              onSelect: (mode) => _run(context, () => onFanChange(mode)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  final String label;
  final List<String> modes;
  final String? selected;
  final bool busy;
  final void Function(String mode) onSelect;

  const _ControlGroup({
    required this.label,
    required this.modes,
    this.selected,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        CompactModeRow(modes: modes, selected: selected, disabled: busy, onSelect: onSelect),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

String _formatTemp(double? value) => value == null ? '—' : '${value.round()}°F';
