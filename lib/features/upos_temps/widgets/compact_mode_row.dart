import 'package:flutter/material.dart';

/// A single-row (never wraps), compact set of mode buttons — shared by the bulk control card and
/// the per-thermostat detail sheet's System/Fan groups. Each button shares the row equally via
/// Expanded, with tight padding/min-size overrides since Material buttons default to a much
/// taller minimum tap target than this compact layout wants.
class CompactModeRow extends StatelessWidget {
  final List<String> modes;
  final bool disabled;
  final void Function(String mode) onSelect;

  const CompactModeRow({super.key, required this.modes, required this.disabled, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
    return Row(
      children: [
        for (int i = 0; i < modes.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              style: style,
              onPressed: disabled ? null : () => onSelect(modes[i]),
              child: FittedBox(child: Text(modes[i])),
            ),
          ),
        ],
      ],
    );
  }
}
