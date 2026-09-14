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

  void _validate(RecurringTransactionRecord r) {
    if (r.name.trim().isEmpty ||
        !r.amount.isFinite ||
        r.amount <= 0 ||
        r.amount > 999999999.99) {
      throw ArgumentError(
        'Enter a name and an amount from 0.01 to 999,999,999.99.',
      );
    }
    if (r.intervalCount < 1 || r.intervalCount > 120) {
      throw ArgumentError('Choose an interval from 1 to 120.');
    }
    if (!r.includes(r.startDate)) {
      throw ArgumentError('End date cannot be before the start date.');
    }
  }

  Future<int> insert(RecurringTransactionRecord r) async {
    _validate(r);
    final row = Map<String, Object?>.from(r.toRow())..remove('id');
    // New rules always begin at their configured start, with no posted history.
    row['next_run_at'] = r.startDate.toIso8601String();
    row['last_run_at'] = null;
    return (await db.database).insert('recurring_transactions', row);
  }

  Future<void> update(RecurringTransactionRecord r) async {
    _validate(r);
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [r.id],
      );
      if (rows.isEmpty) {
        throw StateError('This recurring rule no longer exists.');
      }
      final current = RecurringTransactionRecord.fromRow(rows.single);
      final changedCadence =
          current.startDate != r.startDate ||
          current.frequency != r.frequency ||
          current.intervalCount != r.intervalCount;
      final next = changedCadence
          ? (current.lastRunAt == null
                ? r.startDate
                : r.firstAfter(current.lastRunAt!))
          : current.nextRunAt;
      final row = r.toRow();
      // A stale edit must never rewind posting progress or repost old dates.
      row['last_run_at'] = current.lastRunAt?.toIso8601String();
      row['next_run_at'] = next.toIso8601String();
      row['is_active'] = r.isActive && r.includes(next) ? 1 : 0;
      row['updated_at'] = DateTime.now().toIso8601String();
      await txn.update(
        'recurring_transactions',
        row,
        where: 'id = ?',
        whereArgs: [r.id],
      );
    });
  }

  Future<void> delete(int id) async {
    await (await db.database).delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Read due rules, post transactions, update balances and advance progress
  /// under one SQLite transaction. Concurrent/retried runs read the committed
  /// progress; any failure rolls the entire batch back.
  Future<int> postDue(
    TransactionRepo tx,
    DateTime moment, {
    int batchLimit = 1000,
  }) async {
    if (!identical(db, tx.db)) {
      throw ArgumentError(
        'Recurring rules and transactions must share a database.',
      );
    }
    if (batchLimit < 1) throw ArgumentError('Batch limit must be positive.');
    return (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'recurring_transactions',
        where: 'is_active = 1',
        orderBy: 'next_run_at ASC',
      );
      var count = 0;
      for (final row in rows) {
        final rule = RecurringTransactionRecord.fromRow(row);
        if (rule.nextRunAt.isAfter(moment)) continue;
        _validate(rule);
        var next = rule.nextRunAt;
        var last = rule.lastRunAt;
        // Watermark also protects legacy records with stale next_run_at.
        if (last != null && !next.isAfter(last)) next = rule.firstAfter(last);
        while (!next.isAfter(moment) &&
            rule.includes(next) &&
            count < batchLimit) {
          await tx.insertInTransaction(
            txn,
            TxRecord(
              amount: rule.amount,
              type: rule.type,
              category: rule.category,
              account: rule.account,
              occurredAt: next,
              notes: rule.notes == null || rule.notes!.isEmpty
                  ? 'Recurring: ${rule.name}'
                  : '${rule.notes}\n(Recurring: ${rule.name})',
              createdAt: moment,
              updatedAt: moment,
            ),
          );
          last = next;
          final following = rule.computeNextAfter(next);
          if (!following.isAfter(next)) {
            throw StateError('Schedule must advance to a later date.');
          }
          next = following;
          count++;
        }
        await txn.update(
          'recurring_transactions',
          {
            'next_run_at': next.toIso8601String(),
            'last_run_at': last?.toIso8601String(),
            'is_active': rule.includes(next) ? 1 : 0,
            'updated_at': moment.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [rule.id],
        );
        if (count >= batchLimit) break;
      }
      return count;
    });
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
    logger?.info('Posting due recurring transactions atomically.');
    return recurring.postDue(tx, now ?? DateTime.now());
  }
}
