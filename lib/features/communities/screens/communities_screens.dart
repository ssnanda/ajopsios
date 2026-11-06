import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/hoa_models.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';

final _communitiesProvider = FutureProvider.autoDispose<List<HoaCommunity>>((ref) => OpsApi.instance.getHoaCommunities());
final _communityProvider = FutureProvider.autoDispose.family<({String name, List<HoaUnitSummary> units}), String>((ref, id) => OpsApi.instance.getHoaCommunity(id));
final _unitProvider = FutureProvider.autoDispose.family<HoaUnitDetail, int>((ref, id) => OpsApi.instance.getHoaUnit(id));

// ── helpers ──────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

Color _hue(String name, {double l = 0.88}) {
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), 0.55, l).toColor();
}

String _monthYear(String d) {
  final t = DateTime.tryParse(d.length >= 10 ? d.substring(0, 10) : d);
  if (t == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[t.month - 1]} ${t.year}';
}

String _tenure(String start, [String end = '']) {
  final s = DateTime.tryParse(start.length >= 10 ? start.substring(0, 10) : start);
  if (s == null) return '';
  final e = DateTime.tryParse(end.length >= 10 ? end.substring(0, 10) : end) ?? DateTime.now();
  final months = math.max(0, (e.year - s.year) * 12 + e.month - s.month);
  final y = months ~/ 12, m = months % 12;
  if (y == 0) return '${m}m';
  return m == 0 ? '${y}y' : '${y}y ${m}m';
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar(this.name, {this.size = 32});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _hue(name), shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2)),
        child: Text(_initials(name), style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w600, color: _hue(name, l: 0.28))),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ── communities ──────────────────────────────────────────────────────────────

class CommunitiesScreen extends ConsumerWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_communitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Communities')),
      body: async.when(
        loading: () => const AjLoadingIndicator(),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_communitiesProvider)),
        data: (list) {
          final withUnits = list.where((c) => c.units > 0).toList();
          final empty = list.where((c) => c.units == 0).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_communitiesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final c in withUnits) _CommunityCard(c),
                if (empty.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text('NO UNITS YET', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600))),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final c in empty) ActionChip(label: Text(c.name), onPressed: () => context.push('/communities/${Uri.encodeComponent(c.id)}'))]),
                ],
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No communities yet.'))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final HoaCommunity c;
  const _CommunityCard(this.c);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/communities/${Uri.encodeComponent(c.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: c.occupancy, strokeWidth: 6, backgroundColor: scheme.surfaceContainerHighest)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${c.units}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('units', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                ]),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Pill('${c.owners} owners', scheme.surfaceContainerHighest, scheme.onSurface),
                  if (c.vacant > 0) _Pill('${c.vacant} no owner', Colors.amber.shade50, Colors.amber.shade900),
                  if (c.violations > 0) _Pill('${c.violations} violation${c.violations == 1 ? '' : 's'}', Colors.red.shade50, Colors.red.shade800),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}

// ── one community: unit tiles ────────────────────────────────────────────────

class CommunityScreen extends ConsumerStatefulWidget {
  final String id;
  const CommunityScreen({super.key, required this.id});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _q = '';
  String _filter = 'all'; // all | vacant | violations

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_communityProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(async.value?.name ?? 'Community')),
      body: async.when(
        loading: () => const AjLoadingIndicator(),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_communityProvider(widget.id))),
        data: (data) {
          final needle = _q.trim().toLowerCase();
          final shown = data.units.where((u) {
            if (_filter == 'vacant' && u.owners.isNotEmpty) return false;
            if (_filter == 'violations' && u.violations == 0) return false;
            if (needle.isEmpty) return true;
            return u.unit.toLowerCase().contains(needle) || u.address.toLowerCase().contains(needle) || u.owners.any((o) => o.name.toLowerCase().contains(needle) || o.email.toLowerCase().contains(needle));
          }).toList();
          final vacant = data.units.where((u) => u.owners.isEmpty).length;
          final viol = data.units.where((u) => u.violations > 0).length;
          Widget chip(String key, String label, int n) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(label: Text('$label · $n'), selected: _filter == key, onSelected: (_) => setState(() => _filter = _filter == key ? 'all' : key)),
              );
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search unit, address or owner', isDense: true),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [chip('all', 'All units', data.units.length), chip('vacant', 'No owner', vacant), chip('violations', 'Violations', viol)]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('No units match.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _UnitTile(communityId: widget.id, u: shown[i]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  final String communityId;
  final HoaUnitSummary u;
  const _UnitTile({required this.communityId, required this.u});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vacant = u.owners.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/communities/${Uri.encodeComponent(communityId)}/units/${u.id}'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: vacant ? scheme.surfaceContainerLowest : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: vacant ? scheme.outlineVariant : scheme.outlineVariant, width: vacant ? 1.5 : 1),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.unit.isEmpty ? '—' : u.unit, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (u.address.isNotEmpty) Text(u.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const Spacer(),
            if (vacant)
              Text('No current owner', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
            else
              Row(children: [
                for (var i = 0; i < math.min(3, u.owners.length); i++) Align(widthFactor: 0.7, child: _Avatar(u.owners[i].name, size: 26)),
                const SizedBox(width: 10),
                Expanded(child: Text('${u.owners.first.name}${u.owners.length > 1 ? ' +${u.owners.length - 1}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              ]),
            if (u.previousCount > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${u.previousCount} previous', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))),
          ]),
          if (u.violations > 0) Positioned(right: 0, top: 0, child: _Pill('${u.violations}', Colors.red.shade500, Colors.white)),
        ]),
      ),
    );
  }
}

// ── one unit: owners, timeline, violations ───────────────────────────────────

class UnitScreen extends ConsumerWidget {
  final int unitId;
  const UnitScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_unitProvider(unitId));
    return Scaffold(
      appBar: AppBar(title: Text(async.value == null ? 'Unit' : 'Unit ${async.value!.unit}')),
      body: async.when(
        loading: () => const AjLoadingIndicator(),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_unitProvider(unitId))),
        data: (d) => ListView(padding: const EdgeInsets.all(14), children: [
          if (d.address.isNotEmpty || d.communityName.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text([d.address, d.communityName].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const _Heading('CURRENT OWNERS'),
          if (d.current.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No current owner on record.')),
          for (final o in d.current) _OwnerCard(o),
          const _Heading('OWNERSHIP HISTORY'),
          for (var i = 0; i < d.history.length; i++) _TimelineRow(d.history[i], last: i == d.history.length - 1),
          const _Heading('VIOLATIONS'),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Stay with the property, whoever owns it.', style: TextStyle(fontSize: 12))),
          if (d.violations.isEmpty) const Text('No violations on record.'),
          for (final v in d.violations)
            Card(
              child: ListTile(
                title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text([v.number, _monthYear(v.createdAt), if (v.ownersAtTime.isNotEmpty) 'Owner(s) then: ${v.ownersAtTime}'].where((s) => s.isNotEmpty).join(' · ')),
                trailing: v.statusLabel.isEmpty ? null : _Pill(v.statusLabel, v.status == 'completed' ? Colors.green.shade50 : v.status == 'cancelled' ? Colors.grey.shade200 : Colors.amber.shade50, v.status == 'completed' ? Colors.green.shade800 : v.status == 'cancelled' ? Colors.grey.shade700 : Colors.amber.shade900),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _OwnerCard extends StatelessWidget {
  final HoaOwner o;
  const _OwnerCard(this.o);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Avatar(o.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text('Owner since ${_monthYear(o.startDate).isEmpty ? '—' : _monthYear(o.startDate)}${o.startDate.isEmpty ? '' : ' · ${_tenure(o.startDate)}'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (o.email.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${o.email}${o.emailOk ? '' : '  (do not email)'}')),
              if (o.phone.isNotEmpty) Text(o.phone),
              if (o.mailingAddress.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(o.mailingAddress, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final HoaOwner o;
  final bool last;
  const _TimelineRow(this.o, {required this.last});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = o.isCurrent;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Container(width: 14, height: 14, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: current ? scheme.primary : scheme.outline, shape: BoxShape.circle)),
            if (!last) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.name, style: TextStyle(fontWeight: FontWeight.w600, color: current ? null : scheme.onSurfaceVariant)),
              Text('${_monthYear(o.startDate).isEmpty ? '?' : _monthYear(o.startDate)} – ${current ? 'present' : _monthYear(o.endDate)}${o.startDate.isEmpty ? '' : ' · ${_tenure(o.startDate, o.endDate)}'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (o.notes.isNotEmpty) Text(o.notes, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ]),
    );
  }
}
