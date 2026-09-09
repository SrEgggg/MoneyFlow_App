import 'enums.dart';

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
  }) =>
      BudgetRecord(
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

  static RecurringFrequency fromId(String id) =>
      RecurringFrequency.values.firstWhere(
        (e) => e.id == id,
        orElse: () => RecurringFrequency.monthly,
      );

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

  /// Advance [from] to the next run after the current [nextRunAt].
  /// Honours [intervalCount] (every N units) and [endDate].
  DateTime computeNextAfter(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return DateTime(from.year, from.month, from.day + intervalCount,
            from.hour, from.minute);
      case RecurringFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7 * intervalCount,
            from.hour, from.minute);
      case RecurringFrequency.monthly:
        // Clamp the day-of-month so Feb 30 → Feb 28/29 rather than overflowing
        // into March.
        final month = from.month + intervalCount;
        final year = from.year + ((month - 1) ~/ 12);
        final normalizedMonth = ((month - 1) % 12) + 1;
        final lastDayOfTarget = DateTime(year, normalizedMonth + 1, 0).day;
        final day = from.day <= lastDayOfTarget ? from.day : lastDayOfTarget;
        return DateTime(year, normalizedMonth, day, from.hour, from.minute);
    }
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
    DateTime? endDate,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    bool? isActive,
    String? notes,
    DateTime? updatedAt,
  }) =>
      RecurringTransactionRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        account: account ?? this.account,
        frequency: frequency ?? this.frequency,
        intervalCount: intervalCount ?? this.intervalCount,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        nextRunAt: nextRunAt ?? this.nextRunAt,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
