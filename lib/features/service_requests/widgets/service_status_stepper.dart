import 'package:flutter/material.dart';
import '../../../core/models/ops_service_request_model.dart';

/// Same design as both web apps: every step gets its own label (no
/// tooltips/hover needed), "cancelled" is a separate off-ramp rather than a
/// forward step, and tapping any step (including a past one) jumps directly
/// to it.
class ServiceStatusStepper extends StatelessWidget {
  final OpsServiceRequest request;
  final bool busy;
  final void Function(String newStatus) onChange;

  const ServiceStatusStepper({
    super.key,
    required this.request,
    required this.busy,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (request.serviceStatus == 'cancelled') {
      return GestureDetector(
        onTap: busy ? null : () {
          final steps = request.pipelineSteps;
          onChange(steps.isNotEmpty ? steps.first.key : 'new');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Cancelled — tap to reopen',
            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
    }

    final steps = request.pipelineSteps;
    final currentIdx = steps.indexWhere((e) => e.key == request.serviceStatus);

    return Opacity(
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
              width: 78,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: busy ? null : () => onChange(steps[i].key),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < currentIdx
                            ? Colors.green
                            : i == currentIdx
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                        border: i == currentIdx
                            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 5)
                            : null,
                      ),
                      child: i < currentIdx
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].value,
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
          ],
        ],
      ),
    );
  }
}
