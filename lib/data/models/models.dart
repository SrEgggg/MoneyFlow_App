import 'enums.dart';

const _unchangedTxField = Object();

/// Plain data class for a transaction. Stored as a row in `transactions`.
class TxRecord {
  final int? id;
  final double amount;
  final TxType type;
  final String category;
  final String account;
  final String? destinationAccount;
  final DateTime occurredAt;
  final String? notes;
  final String? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TxRecord({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.account,
    this.destinationAccount,
    required this.occurredAt,
    this.notes,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Signed amount (income positive, expense negative) for aggregation.
  double get signed => type == TxType.transfer
      ? 0
      : type == TxType.income
      ? amount.abs()
      : -amount.abs();

  /// Used in the "+" / "-" display.
  String get displayAmount => type == TxType.transfer
      ? '↔ ${amount.toStringAsFixed(2)}'
      : type == TxType.income
      ? '+${amount.toStringAsFixed(0)}'
      : '-${amount.toStringAsFixed(0)}';

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'amount': amount.abs(),
    'type': type.id,
    'category': category,
    'account': account,
    'destination_account': destinationAccount,
    'occurred_at': occurredAt.toIso8601String(),
    'notes': notes,
    'tags': tags,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TxRecord.fromRow(Map<String, Object?> r) => TxRecord(
    id: r['id'] as int?,
    amount: (r['amount'] as num).toDouble(),
    type: TxType.fromId(r['type'] as String),
    category: r['category'] as String,
    account: r['account'] as String,
    destinationAccount: r['destination_account'] as String?,
    occurredAt: DateTime.parse(r['occurred_at'] as String),
    notes: r['notes'] as String?,
    tags: r['tags'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  TxRecord copyWith({
    int? id,
    double? amount,
    TxType? type,
    String? category,
    String? account,
    String? destinationAccount,
    DateTime? occurredAt,
    Object? notes = _unchangedTxField,
    Object? tags = _unchangedTxField,
    DateTime? updatedAt,
  }) => TxRecord(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    category: category ?? this.category,
    account: account ?? this.account,
    destinationAccount: destinationAccount ?? this.destinationAccount,
    occurredAt: occurredAt ?? this.occurredAt,
    notes: identical(notes, _unchangedTxField) ? this.notes : notes as String?,
    tags: identical(tags, _unchangedTxField) ? this.tags : tags as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Goal data record.
class GoalRecord {
  final int? id;
  final String name;
  final String? photo; // bounded base64 PNG, included in backups
  final GoalKind kind;
  final String icon; // icon code as string for portability
  final double targetAmount;
  final double currentAmount;
  final double? monthlyTarget;
  final DateTime startedAt;
  final DateTime? targetDate;
  final GoalStatus status;
  final DateTime? completedAt;
  final int sortOrder;

  const GoalRecord({
    this.id,
    required this.name,
    this.photo,
    required this.kind,
    required this.icon,
    required this.targetAmount,
    required this.currentAmount,
    this.monthlyTarget,
    required this.startedAt,
    this.targetDate,
    required this.status,
    this.completedAt,
    this.sortOrder = 0,
  });

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0, 1);
  }

  bool get isActive => status == GoalStatus.active;
  bool get isCompleted => status == GoalStatus.completed;

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'name': name,
    'photo': photo,
    'kind': kind.id,
    'icon': icon,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'monthly_target': monthlyTarget,
    'started_at': startedAt.toIso8601String(),
    'target_date': targetDate?.toIso8601String(),
    'status': status.id,
    'completed_at': completedAt?.toIso8601String(),
    'sort_order': sortOrder,
  };

  factory GoalRecord.fromRow(Map<String, Object?> r) => GoalRecord(
    id: r['id'] as int?,
    name: r['name'] as String,
    photo: r['photo'] as String?,
    kind: GoalKind.fromId(r['kind'] as String),
    icon: r['icon'] as String,
    targetAmount: (r['target_amount'] as num).toDouble(),
    currentAmount: (r['current_amount'] as num).toDouble(),
    monthlyTarget: (r['monthly_target'] as num?)?.toDouble(),
    startedAt: DateTime.parse(r['started_at'] as String),
    targetDate: r['target_date'] == null
        ? null
        : DateTime.tryParse(r['target_date'] as String),
    status: GoalStatus.fromId(r['status'] as String),
    completedAt: r['completed_at'] == null
        ? null
        : DateTime.parse(r['completed_at'] as String),
    sortOrder: (r['sort_order'] as int?) ?? 0,
  );

  GoalRecord copyWith({
    int? id,
    String? name,
    String? photo,
    bool clearPhoto = false,
    GoalKind? kind,
    String? icon,
    double? targetAmount,
    double? currentAmount,
    double? monthlyTarget,
    DateTime? startedAt,
    DateTime? targetDate,
    GoalStatus? status,
    DateTime? completedAt,
    int? sortOrder,
  }) => GoalRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    photo: clearPhoto ? null : photo ?? this.photo,
    kind: kind ?? this.kind,
    icon: icon ?? this.icon,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    monthlyTarget: monthlyTarget ?? this.monthlyTarget,
    startedAt: startedAt ?? this.startedAt,
    targetDate: targetDate ?? this.targetDate,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// Single goal contribution event.
class GoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime contributedAt;
  final String? notes;

  const GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.contributedAt,
    this.notes,
  });

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'goal_id': goalId,
    'amount': amount,
    'contributed_at': contributedAt.toIso8601String(),
    'notes': notes,
  };

  factory GoalContribution.fromRow(Map<String, Object?> r) => GoalContribution(
    id: r['id'] as int?,
    goalId: r['goal_id'] as int,
    amount: (r['amount'] as num).toDouble(),
    contributedAt: DateTime.parse(r['contributed_at'] as String),
    notes: r['notes'] as String?,
  );
}

/// A single day's performance summary, recomputed from transactions.
class DailyPerformance {
  final DateTime date; // financial-day key, normalized to midnight
  final double income;
  final double expenses;
  final double savedAmount;
  final double allowance;
  final String status; // dark_green | green | yellow | red | dark_red
  final String? notes;
  final DateTime computedAt;

  const DailyPerformance({
    required this.date,
    required this.income,
    required this.expenses,
    required this.savedAmount,
    required this.allowance,
    required this.status,
    this.notes,
    required this.computedAt,
  });

  Map<String, Object?> toRow() => {
    'date': _isoDate(date),
    'income': income,
    'expenses': expenses,
    'saved_amount': savedAmount,
    'allowance': allowance,
    'status': status,
    'notes': notes,
    'computed_at': computedAt.toIso8601String(),
  };

  factory DailyPerformance.fromRow(Map<String, Object?> r) => DailyPerformance(
    date: DateTime.parse(r['date'] as String),
    income: (r['income'] as num).toDouble(),
    expenses: (r['expenses'] as num).toDouble(),
    savedAmount: (r['saved_amount'] as num).toDouble(),
    allowance: (r['allowance'] as num).toDouble(),
    status: r['status'] as String,
    notes: r['notes'] as String?,
    computedAt: DateTime.parse(r['computed_at'] as String),
  );

  static String _isoDate(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();
}

/// Journal entry.
class JournalRecord {
  final int? id;
  final DateTime entryDate;
  final String mood;
  final String? title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalRecord({
    this.id,
    required this.entryDate,
    required this.mood,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'entry_date': DateTime(
      entryDate.year,
      entryDate.month,
      entryDate.day,
    ).toIso8601String(),
    'mood': mood,
    'title': title,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory JournalRecord.fromRow(Map<String, Object?> r) => JournalRecord(
    id: r['id'] as int?,
    entryDate: DateTime.parse(r['entry_date'] as String),
    mood: r['mood'] as String,
    title: r['title'] as String?,
    content: r['content'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );
}

/// Account record.
class AccountRecord {
  final int? id;
  final String name;
  final String type; // cash | bank | ewallet
  final double balance;
  final String color; // hex
  final int sortOrder;

  const AccountRecord({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.sortOrder = 0,
  });

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'balance': balance,
    'color': color,
    'sort_order': sortOrder,
  };

  factory AccountRecord.fromRow(Map<String, Object?> r) => AccountRecord(
    id: r['id'] as int?,
    name: r['name'] as String,
    type: r['type'] as String,
    balance: (r['balance'] as num).toDouble(),
    color: r['color'] as String,
    sortOrder: (r['sort_order'] as int?) ?? 0,
  );
}

/// Streak record.
class StreakRecord {
  final String id; // 'saving' | 'logging' | 'goal'
  final int currentCount;
  final int bestCount;
  final DateTime? lastQualifiedDay;

  const StreakRecord({
    required this.id,
    required this.currentCount,
    required this.bestCount,
    this.lastQualifiedDay,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'current_count': currentCount,
    'best_count': bestCount,
    'last_qualified_day': lastQualifiedDay?.toIso8601String(),
  };

  factory StreakRecord.fromRow(Map<String, Object?> r) => StreakRecord(
    id: r['id'] as String,
    currentCount: (r['current_count'] as num).toInt(),
    bestCount: (r['best_count'] as num).toInt(),
    lastQualifiedDay: r['last_qualified_day'] == null
        ? null
        : DateTime.parse(r['last_qualified_day'] as String),
  );
}

/// Settings single-row record.
class SettingsRecord {
  final String displayName;
  final int cutoffHour;
  final String currency;
  final String themeMode;

  const SettingsRecord({
    required this.displayName,
    required this.cutoffHour,
    required this.currency,
    this.themeMode = 'system',
  });

  SettingsRecord copyWith({
    String? displayName,
    int? cutoffHour,
    String? currency,
    String? themeMode,
  }) => SettingsRecord(
    displayName: displayName ?? this.displayName,
    cutoffHour: cutoffHour ?? this.cutoffHour,
    currency: currency ?? this.currency,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, Object?> toRow() => {
    'id': 1,
    'display_name': displayName,
    'cutoff_hour': cutoffHour,
    'currency': currency,
    'theme_mode': themeMode,
  };

  factory SettingsRecord.fromRow(Map<String, Object?> r) => SettingsRecord(
    displayName: r['display_name'] as String,
    cutoffHour: (r['cutoff_hour'] as num).toInt(),
    currency: r['currency'] as String,
    themeMode: r['theme_mode'] as String? ?? 'system',
  );
}

/// One entry of the transaction audit log.
class RevisionRecord {
  final int? id;
  final int transactionId;
  final String oldValues; // JSON
  final String newValues; // JSON
  final DateTime changedAt;

  const RevisionRecord({
    this.id,
    required this.transactionId,
    required this.oldValues,
    required this.newValues,
    required this.changedAt,
  });

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'transaction_id': transactionId,
    'old_values': oldValues,
    'new_values': newValues,
    'changed_at': changedAt.toIso8601String(),
  };

  factory RevisionRecord.fromRow(Map<String, Object?> r) => RevisionRecord(
    id: r['id'] as int?,
    transactionId: r['transaction_id'] as int,
    oldValues: r['old_values'] as String,
    newValues: r['new_values'] as String,
    changedAt: DateTime.parse(r['changed_at'] as String),
  );
}

/// One earned achievement.
class EarnedAchievement {
  final int? id;
  final String achievementId;
  final DateTime earnedAt;

  const EarnedAchievement({
    this.id,
    required this.achievementId,
    required this.earnedAt,
  });

  factory EarnedAchievement.fromRow(Map<String, Object?> r) =>
      EarnedAchievement(
        id: r['id'] as int?,
        achievementId: r['achievement_id'] as String,
        earnedAt: DateTime.parse(r['earned_at'] as String),
      );
}
