import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/modules_provider.dart';

/// Sub-pipelines under Pipeline: key, label, route, module the site must offer (null = always).
const kPipelineViews = [
  (key: 'filings', label: 'Filings', path: '/pipeline', module: null),
  (key: 'purchases', label: 'Purchases', path: '/pipeline/purchases', module: 'purchases'),
  (key: 'invoices', label: 'Invoices', path: '/pipeline/invoices', module: 'invoices'),
  (key: 'insurance', label: 'Insurance & HOA', path: '/pipeline/insurance', module: 'insurance'),
];

/// Switch between the sub-pipelines the site offers (hidden when there is only Filings).
class PipelineSwitch extends ConsumerWidget {
  final String current; // a kPipelineViews key
  const PipelineSwitch({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider).value;
    final views = kPipelineViews.where((v) => v.module == null || (modules?.contains(v.module) ?? false)).toList();
    if (views.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        for (final v in views)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(v.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              selected: v.key == current,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onSelected: (_) {
                if (v.key != current) context.go(v.path);
              },
            ),
          ),
      ]),
    );
  }
}
