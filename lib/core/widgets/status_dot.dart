import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Round color dot for day status (calendar legend, calendar tiles).
class StatusDot extends StatelessWidget {
  final DayStatus status;
  final double size;
  final bool outlined;
  const StatusDot({
    super.key,
    required this.status,
    this.size = 12,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: color, width: 1.5) : null,
      ),
    );
  }

  static Color colorForStatus(DayStatus s) => _colorFor(s);
  static Color _colorFor(DayStatus s) => switch (s) {
    DayStatus.darkGreen => AppColors.dayDarkGreen,
    DayStatus.green => AppColors.dayGreen,
    DayStatus.yellow => AppColors.dayYellow,
    DayStatus.red => AppColors.dayRed,
    DayStatus.darkRed => AppColors.dayDarkRed,
    DayStatus.none => AppColors.dayEmpty,
  };
}

/// Day status (mirrors the strings stored in `daily_performance_cache.status`).
enum DayStatus {
  darkGreen,
  green,
  yellow,
  red,
  darkRed,
  none;

  String get id => name;

  static DayStatus fromId(String? id) {
    if (id == null) return DayStatus.none;
    return DayStatus.values.firstWhere(
      (d) => d.id == id,
      orElse: () => DayStatus.none,
    );
  }
}
