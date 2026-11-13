import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Filings | Purchases switch shown under the Pipeline app bar (Purchases only when the site offers it).
class PipelineSwitch extends StatelessWidget {
  final bool purchases; // true = Purchases is the current view
  const PipelineSwitch({super.key, required this.purchases});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on, String path) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            selected: on,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            onSelected: (_) {
              if (!on) context.go(path);
            },
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [chip('Filings', !purchases, '/pipeline'), chip('Purchases', purchases, '/pipeline/purchases')]),
    );
  }
}
