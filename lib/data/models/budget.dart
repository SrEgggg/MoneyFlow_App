import 'enums.dart';

const _unchangedRecurringValue = Object();

/// Per-category spending cap. A `monthKey` of null means the budget applies
/// to whatever the current calendar month is (rolling). A value like
/// `'2026-08'` pins it to that specific month.
class BudgetRecord {
  final int? id;
  final String category;
  final double amount;
  final String? monthKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetRecord({
    this.id,
    required this.category,
    required this.amount,
    this.monthKey,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'category': category,
    'amount': amount,
    'month_key': monthKey,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory BudgetRecord.fromRow(Map<String, Object?> r) => BudgetRecord(
    id: r['id'] as int?,
    category: r['category'] as String,
    amount: (r['amount'] as num).toDouble(),
    monthKey: r['month_key'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  BudgetRecord copyWith({
    int? id,
    String? category,
    double? amount,
    String? monthKey,
    DateTime? updatedAt,
  }) => BudgetRecord(
    id: id ?? this.id,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    monthKey: monthKey ?? this.monthKey,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Frequency unit for a [RecurringTransactionRecord].
enum RecurringFrequency {
  daily,
  weekly,
  monthly;

  String get id => name;

  static RecurringFrequency fromId(String id) => RecurringFrequency.values
      .firstWhere((e) => e.id == id, orElse: () => RecurringFrequency.monthly);

  String get label => switch (this) {
    RecurringFrequency.daily => 'Daily',
    RecurringFrequency.weekly => 'Weekly',
    RecurringFrequency.monthly => 'Monthly',
  };
}

/// A rule that materializes a transaction on a cadence (salary, rent,
/// subscriptions). `nextRunAt` is advanced after every successful
/// materialization; rules with an `endDate` past today auto-deactivate.
class RecurringTransactionRecord {
  final int? id;
  final String name;
  final double amount;
  final TxType type;
  final String category;
  final String account;
  final RecurringFrequency frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextRunAt;
  final DateTime? lastRunAt;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransactionRecord({
    this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.account,
    required this.frequency,
    this.intervalCount = 1,
    required this.startDate,
    this.endDate,
    required this.nextRunAt,
    this.lastRunAt,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Human-friendly label: "Every 2 weeks" / "Every month".
  String get cadenceLabel {
    final n = intervalCount <= 0 ? 1 : intervalCount;
    final unit = switch (frequency) {
      RecurringFrequency.daily => n == 1 ? 'day' : 'days',
      RecurringFrequency.weekly => n == 1 ? 'week' : 'weeks',
      RecurringFrequency.monthly => n == 1 ? 'month' : 'months',
    };
    return 'Every $n $unit';
  }

  /// Advance one period, preserving local clock time and the original monthly
  /// day (Jan 31 -> Feb 28 -> Mar 31). End dates are checked by the runner.
  DateTime computeNextAfter(DateTime from) {
    if (intervalCount < 1 || intervalCount > 120) {
      throw ArgumentError('Choose an interval from 1 to 120.');
    }
    DateTime at(int year, int month, int day) => from.isUtc
        ? DateTime.utc(
            year,
            month,
            day,
            from.hour,
            from.minute,
            from.second,
            from.millisecond,
            from.microsecond,
          )
        : DateTime(
            year,
            month,
            day,
            from.hour,
            from.minute,
            from.second,
            from.millisecond,
            from.microsecond,
          );
    switch (frequency) {
      case RecurringFrequency.daily:
        return at(from.year, from.month, from.day + intervalCount);
      case RecurringFrequency.weekly:
        return at(from.year, from.month, from.day + 7 * intervalCount);
      case RecurringFrequency.monthly:
        final target = at(from.year, from.month + intervalCount, 1);
        final lastDay = at(target.year, target.month + 1, 0).day;
        final day = startDate.day <= lastDay ? startDate.day : lastDay;
        return at(target.year, target.month, day);
    }
  }

  /// First occurrence on this cadence strictly after a posted instant.
  DateTime firstAfter(DateTime posted) {
    if (startDate.isAfter(posted)) return startDate;
    final start = startDate;
    final end = startDate.isUtc ? posted.toUtc() : posted.toLocal();
    final elapsedDays = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final periods = switch (frequency) {
      RecurringFrequency.daily => elapsedDays ~/ intervalCount,
      RecurringFrequency.weekly => elapsedDays ~/ (7 * intervalCount),
      RecurringFrequency.monthly =>
        ((end.year - start.year) * 12 + end.month - start.month) ~/
            intervalCount,
    };
    // Jump close to the answer rather than iterating over years of history.
    final units = periods < 0 ? 0 : periods;
    DateTime candidate;
    if (units == 0) {
      candidate = startDate;
    } else {
      // The jump is arithmetic, not a user cadence; use the normal cadence
      // below to preserve bounds and monthly anchoring.
      final days = frequency == RecurringFrequency.weekly
          ? 7 * units * intervalCount
          : units * intervalCount;
      final base = startDate;
      DateTime at(int y, int m, int d) => base.isUtc
          ? DateTime.utc(
              y,
              m,
              d,
              base.hour,
              base.minute,
              base.second,
              base.millisecond,
              base.microsecond,
            )
          : DateTime(
              y,
              m,
              d,
              base.hour,
              base.minute,
              base.second,
              base.millisecond,
              base.microsecond,
            );
      if (frequency == RecurringFrequency.monthly) {
        final month = at(base.year, base.month + units * intervalCount, 1);
        final lastDay = at(month.year, month.month + 1, 0).day;
        candidate = at(
          month.year,
          month.month,
          base.day <= lastDay ? base.day : lastDay,
        );
      } else {
        candidate = at(base.year, base.month, base.day + days);
      }
    }
    while (!candidate.isAfter(posted)) {
      candidate = computeNextAfter(candidate);
    }
    return candidate;
  }

  bool includes(DateTime occurrence) {
    if (endDate == null) return true;
    final end = endDate!.toLocal();
    final day = occurrence.toLocal();
    return !DateTime(
      day.year,
      day.month,
      day.day,
    ).isAfter(DateTime(end.year, end.month, end.day));
  }

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'name': name,
    'amount': amount,
    'type': type.id,
    'category': category,
    'account': account,
    'frequency': frequency.id,
    'interval_count': intervalCount,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'next_run_at': nextRunAt.toIso8601String(),
    'last_run_at': lastRunAt?.toIso8601String(),
    'is_active': isActive ? 1 : 0,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory RecurringTransactionRecord.fromRow(Map<String, Object?> r) =>
      RecurringTransactionRecord(
        id: r['id'] as int?,
        name: r['name'] as String,
        amount: (r['amount'] as num).toDouble(),
        type: TxType.fromId(r['type'] as String),
        category: r['category'] as String,
        account: r['account'] as String,
        frequency: RecurringFrequency.fromId(r['frequency'] as String),
        intervalCount: (r['interval_count'] as num).toInt(),
        startDate: DateTime.parse(r['start_date'] as String),
        endDate: r['end_date'] == null
            ? null
            : DateTime.parse(r['end_date'] as String),
        nextRunAt: DateTime.parse(r['next_run_at'] as String),
        lastRunAt: r['last_run_at'] == null
            ? null
            : DateTime.parse(r['last_run_at'] as String),
        isActive: ((r['is_active'] as num).toInt()) == 1,
        notes: r['notes'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  RecurringTransactionRecord copyWith({
    int? id,
    String? name,
    double? amount,
    TxType? type,
    String? category,
    String? account,
    RecurringFrequency? frequency,
    int? intervalCount,
    DateTime? startDate,
    Object? endDate = _unchangedRecurringValue,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    bool? isActive,
    Object? notes = _unchangedRecurringValue,
    DateTime? updatedAt,
  }) => RecurringTransactionRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    category: category ?? this.category,
    account: account ?? this.account,
    frequency: frequency ?? this.frequency,
    intervalCount: intervalCount ?? this.intervalCount,
    startDate: startDate ?? this.startDate,
    endDate: identical(endDate, _unchangedRecurringValue)
        ? this.endDate
        : endDate as DateTime?,
    nextRunAt: nextRunAt ?? this.nextRunAt,
    lastRunAt: lastRunAt ?? this.lastRunAt,
    isActive: isActive ?? this.isActive,
    notes: identical(notes, _unchangedRecurringValue)
        ? this.notes
        : notes as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
