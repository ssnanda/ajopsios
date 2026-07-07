import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeStyle style;

  const StatusBadge({
    super.key,
    required this.label,
    this.style = StatusBadgeStyle.neutral,
  });

  factory StatusBadge.fromStatus(String status) {
    final s = status.toLowerCase();
    StatusBadgeStyle style;

    if (['active', 'paid', 'completed', 'resolved'].contains(s)) {
      style = StatusBadgeStyle.success;
    } else if (['pending', 'open', 'in_progress', 'processing'].contains(s)) {
      style = StatusBadgeStyle.warning;
    } else if (['overdue', 'failed', 'cancelled', 'error'].contains(s)) {
      style = StatusBadgeStyle.error;
    } else if (['high'].contains(s)) {
      style = StatusBadgeStyle.error;
    } else {
      style = StatusBadgeStyle.neutral;
    }

    return StatusBadge(
      label: _prettify(status),
      style: style,
    );
  }

  static String _prettify(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (style) {
      StatusBadgeStyle.success => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      StatusBadgeStyle.warning => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      StatusBadgeStyle.error => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        ),
      StatusBadgeStyle.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum StatusBadgeStyle { success, warning, error, neutral }
