import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/financial_day.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../data/models/models.dart';

/// Month-view calendar where each day is colored by its daily performance
/// status. Tapping a day navigates to the day-detail screen.
class CalendarGrid extends StatelessWidget {
  final DateTime month; // any day in the target month
  final List<DailyPerformance> days;
  final int cutoffHour;

  const CalendarGrid({
    super.key,
    required this.month,
    required this.days,
    this.cutoffHour = 3,
  });

  @override
  Widget build(BuildContext context) {
    final offset = D.leadingOffset(month);
    final totalDays = D.daysInMonth(month);
    final byDate = {for (final d in days) _k(d.date): d};
    final today = FinancialDay.today();

    final cells = <Widget>[];
    // Header row (Mon, Tue, …)
    const headers = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (final h in headers) {
      cells.add(_HeaderCell(text: h));
    }

    // Leading empties
    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = _k(date);
      final perf = byDate[key];
      final status = DayStatus.fromId(perf?.status);
      final isToday = _k(date) == _k(today);
      cells.add(_DayCell(
        day: day,
        status: status,
        amount: perf?.savedAmount ?? 0,
        isToday: isToday,
        onTap: () => context.push(Routes.performanceDay(date)),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: cells,
    );
  }

  static DateTime _k(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final DayStatus status;
  final double amount;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.status,
    required this.amount,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: _bgFor(status),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: _fgFor(status),
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 12,
              child: Center(
                child: status == DayStatus.none
                    ? const SizedBox.shrink()
                    : StatusDot(status: status, size: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _bgFor(DayStatus s) => switch (s) {
        DayStatus.darkGreen => AppColors.dayDarkGreen.withValues(alpha: 0.85),
        DayStatus.green => AppColors.dayGreen.withValues(alpha: 0.85),
        DayStatus.yellow => AppColors.dayYellow.withValues(alpha: 0.85),
        DayStatus.red => AppColors.dayRed.withValues(alpha: 0.85),
        DayStatus.darkRed => AppColors.dayDarkRed.withValues(alpha: 0.85),
        DayStatus.none => AppColors.surfaceContainerHigh,
      };

  Color _fgFor(DayStatus s) {
    switch (s) {
      case DayStatus.darkGreen:
      case DayStatus.green:
      case DayStatus.yellow:
      case DayStatus.red:
      case DayStatus.darkRed:
        return Colors.white;
      case DayStatus.none:
        return AppColors.onSurfaceVariant;
    }
  }
}