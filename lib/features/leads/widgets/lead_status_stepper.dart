import 'package:flutter/material.dart';
import '../../../core/models/lead_model.dart';

const _branchEligibleFrom = ['engaged', 'tour'];

/// LEAD STATUS stepper — same visual language as service requests' SVC STATUS
/// (ServiceStatusStepper): a row of tap-to-jump circles connected by a bar,
/// with a separate colored badge once the lead reaches a terminal branch.
/// Adds three differences specific to leads (mirrors AJOps web's
/// LeadStatusStepper): the linear stages are per-lead/per-site
/// (lead.linearPipelineStages — e.g. University Office Suites' extra "Tour"
/// step), a "Tour Complete" shortcut back to Engaged, and three terminal
/// branches (Customer/Future Follow-Up/Lost) offered once the lead reaches
/// Engaged (or Tour) rather than being reachable from every stage.
class LeadStatusStepper extends StatelessWidget {
  final Lead lead;
  final bool busy;

  /// 'customer' / 'future_follow_up' / 'lost' need extra input (a linked
  /// customer / a date) collected by the caller before actually saving —
  /// see LeadDetailScreen._setStage.
  final void Function(String stage) onChange;

  const LeadStatusStepper({
    super.key,
    required this.lead,
    required this.busy,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = lead.leadStatus.isEmpty ? 'new' : lead.leadStatus;

    if (current == 'customer' || current == 'lost' || current == 'future_follow_up') {
      return _TerminalBadge(lead: lead, current: current, busy: busy, onReopen: () => onChange('new'));
    }

    final steps = lead.linearPipelineStages;
    final currentIdx = steps.indexOf(current);
    final canBranch = _branchEligibleFrom.contains(current) || currentIdx >= steps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: busy ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Container(
                      width: 20,
                      height: 3,
                      color: i <= currentIdx ? Colors.green.shade300 : theme.colorScheme.outlineVariant,
                    ),
                  ),
                SizedBox(
                  width: 72,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: busy ? null : () => onChange(steps[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < currentIdx
                                  ? Colors.green
                                  : i == currentIdx
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              border: i == currentIdx
                                  ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 4)
                                  : null,
                            ),
                            child: i < currentIdx
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            leadPipelineLabels[steps[i]] ?? steps[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == currentIdx ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (current == 'tour') ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : () => onChange('engaged'),
            child: const Text('Tour Complete — back to Engaged'),
          ),
        ],
        if (canBranch) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: busy ? null : () => onChange('customer'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade900),
                child: const Text('Customer'),
              ),
              FilledButton.tonal(
                onPressed: busy ? null : () => onChange('future_follow_up'),
                style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade100, foregroundColor: Colors.amber.shade900),
                child: const Text('Future Follow-Up'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => onChange('lost'),
                child: const Text('Lost'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TerminalBadge extends StatelessWidget {
  final Lead lead;
  final String current;
  final bool busy;
  final VoidCallback onReopen;

  const _TerminalBadge({required this.lead, required this.current, required this.busy, required this.onReopen});

  @override
  Widget build(BuildContext context) {
    final followUpDue = current == 'future_follow_up' &&
        lead.leadFollowUpAt.isNotEmpty &&
        (DateTime.tryParse(lead.leadFollowUpAt)?.isBefore(DateTime.now()) ?? false);

    final Color bg;
    final Color fg;
    switch (current) {
      case 'customer':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
      case 'lost':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
      default: // future_follow_up
        bg = followUpDue ? Colors.red.shade100 : Colors.amber.shade100;
        fg = followUpDue ? Colors.red.shade900 : Colors.amber.shade900;
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        GestureDetector(
          onTap: busy ? null : onReopen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '${leadPipelineLabels[current] ?? current} — tap to reopen',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
        if (current == 'customer' && lead.customerName.isNotEmpty)
          Text('→ ${lead.customerName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        if (current == 'future_follow_up' && lead.leadFollowUpAt.isNotEmpty)
          Text(
            (followUpDue ? 'Due ' : '') + _fmtDate(lead.leadFollowUpAt),
            style: TextStyle(
              color: followUpDue ? Colors.red.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.month}/${d.day}/${d.year}';
}
