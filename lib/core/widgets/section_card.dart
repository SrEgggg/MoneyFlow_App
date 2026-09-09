import 'package:flutter/material.dart';

import '../../app/theme.dart';
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

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.margin = EdgeInsets.zero,
    this.background,
    this.onTap,
    this.titleIcon,
    this.titleIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      padding: padding,
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
                      color: (titleIconColor ?? AppColors.primary)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      titleIcon,
                      color: titleIconColor ?? AppColors.primary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
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
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
          style: valueStyle ??
              const TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ).copyWith(color: valueColor ?? AppColors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: labelStyle ??
              const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
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
              Text(e.$2,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  )),
            ],
          ),
      ],
    );
  }
}
