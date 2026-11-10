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
      return _TerminalBadge(lead: lead, current: current, busy: busy, onChange: onChange);
    }

    // 'auto_reached' (cron) and 'reached' (manual) are parallel alternatives that both lead to
    // Engaged — grouped into one forked step; every other stage is a group of one.
    final groups = <List<String>>[];
    for (final k in lead.linearPipelineStages) {
      if (k == 'reached' && groups.isNotEmpty && groups.last.contains('auto_reached')) {
        groups.last.add(k);
      } else {
        groups.add([k]);
      }
    }
    final currentIdx = groups.indexWhere((g) => g.contains(current));
    final canBranch = _branchEligibleFrom.contains(current) || currentIdx >= groups.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: busy ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < groups.length; i++) ...[
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
                  width: groups[i].length > 1 && i >= currentIdx ? 88 : 72,
                  child: Column(
                    children: [
                      // Past the fork the branch taken isn't known — one "Reached" check, not both.
                      for (final key in (i < currentIdx && groups[i].length > 1 ? const ['reached'] : groups[i]))
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: busy ? null : () => onChange(key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < currentIdx
                                        ? Colors.green
                                        : key == current
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surfaceContainerHighest,
                                    border: key == current
                                        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 4)
                                        : null,
                                  ),
                                  child: i < currentIdx
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  leadPipelineLabels[key] ?? key,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: key == current ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
          const SizedBox(height: 8),
          // One compact row of three equal buttons (icon + short label), grey until chosen —
          // 40px tall keeps them easy to tap without the old full-width, 52px-each stack.
          Row(
            children: [
              Expanded(child: _BranchButton(icon: Icons.check_circle_outline_rounded, label: 'Customer', busy: busy, onTap: () => onChange('customer'))),
              const SizedBox(width: 8),
              Expanded(child: _BranchButton(icon: Icons.event_repeat_rounded, label: 'Follow-Up', busy: busy, onTap: () => onChange('future_follow_up'))),
              const SizedBox(width: 8),
              Expanded(child: _BranchButton(icon: Icons.cancel_outlined, label: 'Lost', busy: busy, onTap: () => onChange('lost'))),
            ],
          ),
        ],
      ],
    );
  }
}

class _BranchButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const _BranchButton({required this.icon, required this.label, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // AjTheme sets an infinite-width minimumSize on buttons (see lead_detail_screen's note on
    // Add Note) — override it so these size to their Expanded slot instead.
    return FilledButton.tonalIcon(
      onPressed: busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade800,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TerminalBadge extends StatelessWidget {
  final Lead lead;
  final String current;
  final bool busy;

  /// Same callback the stepper's steps use — LeadDetailScreen._setStage already handles
  /// 'future_follow_up' generically (shows the date picker, saves whatever status is passed
  /// with the picked date) regardless of the lead's current status, so re-passing
  /// 'future_follow_up' here to change the date doesn't need a separate code path.
  final void Function(String stage) onChange;

  const _TerminalBadge({required this.lead, required this.current, required this.busy, required this.onChange});

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

    final isFollowUp = current == 'future_follow_up';

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        GestureDetector(
          // Used to always reopen (reset to New) on tap, even for Future Follow-Up — which meant
          // "I just want to update the date" silently reset the whole lead's status. Tapping the
          // chip now edits the date instead; reopening moved to its own explicit "Reopen" tap target.
          onTap: busy ? null : () => onChange(isFollowUp ? 'future_follow_up' : 'new'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '${leadPipelineLabels[current] ?? current} — tap to ${isFollowUp ? 'change date' : 'reopen'}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
        if (current == 'customer' && lead.customerName.isNotEmpty)
          Text('→ ${lead.customerName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        if (isFollowUp && lead.leadFollowUpAt.isNotEmpty)
          Text(
            (followUpDue ? 'Due ' : '') + _fmtDate(lead.leadFollowUpAt),
            style: TextStyle(
              color: followUpDue ? Colors.red.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        if (isFollowUp)
          GestureDetector(
            onTap: busy ? null : () => onChange('new'),
            child: Text(
              'Reopen',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, decoration: TextDecoration.underline),
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
