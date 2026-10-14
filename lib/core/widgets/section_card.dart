import 'app_ui.dart';
import 'package:flutter/material.dart';

import 'status_dot.dart';

/// Reusable card surface with optional title row. Premium dark card with
/// subtle radius, generous padding, and consistent typography scale.
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? background;
  final VoidCallback? onTap;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final bool framed;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.margin = EdgeInsets.zero,
    this.background,
    this.onTap,
    this.titleIcon,
    this.titleIconColor,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: framed
          ? BoxDecoration(
              color:
                  background ?? Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.35),
                width: 1,
              ),
            )
          : null,
      padding: framed ? padding : EdgeInsets.zero,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (titleIcon != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          (titleIconColor ??
                                  Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      titleIcon,
                      color:
                          titleIconColor ??
                          Theme.of(context).colorScheme.primary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Mini key/value row inside cards.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final CrossAxisAlignment align;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelStyle,
    this.valueStyle,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          value,
          style:
              valueStyle ??
              TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ).copyWith(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style:
              labelStyle ??
              TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Renders the day-status legend (5 dots).
class DayStatusLegend extends StatelessWidget {
  const DayStatusLegend({super.key});
  @override
  Widget build(BuildContext context) {
    const items = <(DayStatus, String)>[
      (DayStatus.darkGreen, 'Excellent'),
      (DayStatus.green, 'Saved'),
      (DayStatus.yellow, 'Break-even'),
      (DayStatus.red, 'Overspent'),
      (DayStatus.darkRed, 'Heavy Overspending'),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final e in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(status: e.$1, size: 10),
              const SizedBox(width: 6),
              Text(
                e.$2,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
