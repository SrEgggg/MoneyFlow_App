import '../../core/utils/money_amount.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/budget.dart';
import '../models/enums.dart';
import '../../core/utils/financial_day.dart';
import '../../core/utils/app_logger.dart';
import '../../providers.dart';

/// Repository for per-category spending caps.
class BudgetRepo {
  final AppDatabase db;
  final AppLogger? logger;
  BudgetRepo(this.db, {this.logger});

  Future<List<BudgetRecord>> all() async {
    final rows = await (await db.database).query(
      'budgets',
      orderBy: 'category ASC, id ASC',
    );
    return rows.map(BudgetRecord.fromRow).toList();
  }

  /// Budgets that apply to the month containing [anchor].
  /// - `monthKey = 'YYYY-MM'` matches exactly that month.
  /// - `monthKey = NULL` matches every month (rolling).
  Future<List<BudgetRecord>> forMonth(DateTime anchor) async {
    final monthKey =
        '${anchor.year.toString().padLeft(4, '0')}'
        '-${anchor.month.toString().padLeft(2, '0')}';
    final rows = await (await db.database).query(
      'budgets',
      where: 'month_key IS NULL OR month_key = ?',
      whereArgs: [monthKey],
      orderBy: 'category ASC',
    );
    return rows.map(BudgetRecord.fromRow).toList();
  }

  Future<int> insert(BudgetRecord b) async {
    MoneyAmount.require(b.amount);
    logger?.info('Inserting budget for ${b.category}');
    final row = Map<String, Object?>.from(b.toRow())..remove('id');
    return (await db.database).insert('budgets', row);
  }

  Future<void> update(BudgetRecord b) async {
    MoneyAmount.require(b.amount);
    logger?.info('Updating budget ${b.id} for ${b.category}');
    await (await db.database).update(
      'budgets',
      b.toRow(),
      where: 'id = ?',
      whereArgs: [b.id],
    );
  }

  Future<void> delete(int id) async {
    logger?.info('Deleting budget $id');
    await (await db.database).delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Sum of expenses per category for the given month. Returned as a map of
  /// `category → spent`. Income transactions are excluded.
  Future<Map<String, double>> spendByCategoryForMonth(
    DateTime anchor, {
    int cutoffHour = 3,
  }) async {
    final start = FinancialDay.startOfMonth(anchor, cutoffHour: cutoffHour);
    final end = FinancialDay.endOfMonth(anchor, cutoffHour: cutoffHour);
    final rows = await (await db.database).rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) AS spent
      FROM transactions
      WHERE type = ? AND occurred_at >= ? AND occurred_at <= ?
      GROUP BY category
      ''',
      [TxType.expense.id, start.toIso8601String(), end.toIso8601String()],
    );
    final out = <String, double>{};
    for (final r in rows) {
      out[r['category'] as String] = (r['spent'] as num).toDouble();
    }
    return out;
  }
}

class BudgetsNotifier extends AsyncNotifier<List<BudgetRecord>> {
  @override
  Future<List<BudgetRecord>> build() async {
    final repo = ref.watch(budgetRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(budgetRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(BudgetRecord b) async {
    final repo = ref.read(budgetRepoProvider);
    await repo.insert(b);
    await refresh();
  }

  Future<void> edit(BudgetRecord b) async {
    final repo = ref.read(budgetRepoProvider);
    await repo.update(b);
    await refresh();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(budgetRepoProvider);
    await repo.delete(id);
    await refresh();
  }
}
