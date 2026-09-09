import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/budget.dart';
import '../models/models.dart';
import '../../core/utils/app_logger.dart';
import '../../providers.dart';
import 'repositories.dart';

/// Repository for recurring transaction rules.
class RecurringRepo {
  final AppDatabase db;
  final AppLogger? logger;
  RecurringRepo(this.db, {this.logger});

  Future<List<RecurringTransactionRecord>> all() async {
    final rows = await (await db.database).query(
      'recurring_transactions',
      orderBy: 'is_active DESC, next_run_at ASC',
    );
    return rows.map(RecurringTransactionRecord.fromRow).toList();
  }

  Future<List<RecurringTransactionRecord>> dueBy(DateTime moment) async {
    final rows = await (await db.database).query(
      'recurring_transactions',
      where: 'is_active = 1 AND next_run_at <= ?',
      whereArgs: [moment.toIso8601String()],
      orderBy: 'next_run_at ASC',
    );
    return rows.map(RecurringTransactionRecord.fromRow).toList();
  }

  Future<int> insert(RecurringTransactionRecord r) async {
    logger?.info('Inserting recurring rule: ${r.name}');
    final row = Map<String, Object?>.from(r.toRow())..remove('id');
    return (await db.database).insert('recurring_transactions', row);
  }

  Future<void> update(RecurringTransactionRecord r) async {
    logger?.info('Updating recurring rule ${r.id}: ${r.name}');
    await (await db.database).update(
      'recurring_transactions',
      r.toRow(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> delete(int id) async {
    logger?.info('Deleting recurring rule $id');
    await (await db.database).delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Persist the post-materialization `nextRunAt` / `lastRunAt`.
  Future<void> advance(
    int id,
    DateTime nextRunAt, {
    DateTime? lastRunAt,
    bool? isActive,
  }) async {
    logger?.info('Advancing recurring rule $id to $nextRunAt');
    final values = <String, Object?>{
      'next_run_at': nextRunAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      if (lastRunAt != null) 'last_run_at': lastRunAt.toIso8601String(),
      if (isActive != null) 'is_active': isActive ? 1 : 0,
    };
    await (await db.database).update(
      'recurring_transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class RecurringNotifier
    extends AsyncNotifier<List<RecurringTransactionRecord>> {
  @override
  Future<List<RecurringTransactionRecord>> build() async {
    final repo = ref.watch(recurringRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(recurringRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(RecurringTransactionRecord r) async {
    final repo = ref.read(recurringRepoProvider);
    await repo.insert(r);
    await refresh();
  }

  Future<void> edit(RecurringTransactionRecord r) async {
    final repo = ref.read(recurringRepoProvider);
    await repo.update(r);
    await refresh();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(recurringRepoProvider);
    await repo.delete(id);
    await refresh();
  }

  Future<void> toggle(RecurringTransactionRecord r) async {
    await edit(r.copyWith(isActive: !r.isActive));
  }
}

/// Materializes any due recurring rules as real transactions and advances
/// the rule's `nextRunAt`. Idempotent — safe to call on every app start.
class RecurringRunner {
  final RecurringRepo recurring;
  final TransactionRepo tx;
  final AppLogger? logger;
  RecurringRunner({required this.recurring, required this.tx, this.logger});

  Future<int> materializeDue({DateTime? now}) async {
    logger?.info('Materializing due recurring transactions...');
    final moment = now ?? DateTime.now();
    final due = await recurring.dueBy(moment);
    var count = 0;
    for (final rule in due) {
      if (rule.id == null) continue;
      logger?.info('Processing rule ${rule.id}: ${rule.name}');
      if (rule.endDate != null && rule.endDate!.isBefore(moment)) {
        await recurring.advance(
          rule.id!,
          rule.nextRunAt,
          isActive: false,
        );
        continue;
      }
      final now = DateTime.now();
      final occurredAt = rule.nextRunAt.isAfter(now)
          ? now
          : rule.nextRunAt;
      await tx.insert(TxRecord(
        amount: rule.amount,
        type: rule.type,
        category: rule.category,
        account: rule.account,
        occurredAt: occurredAt,
        notes: rule.notes == null || rule.notes!.isEmpty
            ? 'Recurring: ${rule.name}'
            : '${rule.notes}\n(Recurring: ${rule.name})',
        createdAt: now,
        updatedAt: now,
      ));
      var next = rule.computeNextAfter(rule.nextRunAt);
      var active = rule.isActive;
      if (rule.endDate != null && next.isAfter(rule.endDate!)) {
        // Final occurrence lands at endDate.
        next = rule.endDate!;
        active = false;
      }
      await recurring.advance(
        rule.id!,
        next,
        lastRunAt: occurredAt,
        isActive: active,
      );
      count++;
    }
    return count;
  }
}
