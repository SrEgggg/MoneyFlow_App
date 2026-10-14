import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../core/constants/achievements.dart';
import '../../core/utils/financial_day.dart';
import '../database/database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/recalculation_service.dart';

/// Initializes the app on first launch with a completely empty state.
///
/// The user starts with no accounts, no goals, no transactions, no journal
/// entries, and no earned achievements. We only ensure that a settings row
/// exists (downstream providers depend on it) and that the achievement
/// catalog is loaded (definitions only — no earned achievements).
class FirstRunInitializer {
  final AppDatabase db;
  FirstRunInitializer(this.db);

  Future<void> ensureInitialized() async {
    final database = await db.database;

    // Default settings row. The user can change the display name from
    // Settings at any time.
    const defaultSettings = SettingsRecord(
      displayName: 'there',
      cutoffHour: 3,
      currency: 'PHP',
    );
    await database.insert(
      'settings',
      defaultSettings.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Seed the static achievement catalog. These are definition rows — not
    // user data — so they survive a "clear data" reset.
    await _seedAchievementDefs(database);
  }

  Future<void> _seedAchievementDefs(DatabaseExecutor database) async {
    for (final def in AchievementDefs.all) {
      await database.insert('achievement_definitions', {
        'id': def.id,
        'name': def.name,
        'description': def.description,
        'icon_code': def.icon.codePoint,
        'color_value': def.color.toARGB32(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

/// Supplies synthetic records for the debug-only demo reset and tests.
/// Normal first launch uses [FirstRunInitializer] and starts empty.
class SeedRunner {
  final AppDatabase db;
  SeedRunner(this.db);

  Future<void> ensureSeeded() async {
    // No-op: first-run init no longer seeds demo data. Kept so older
    // call-sites that still invoke `ensureSeeded` compile cleanly.
  }

  /// Wipe every user-data table and re-seed from scratch. Used by the
  /// "Reset demo data" button in Settings.
  Future<void> reseed() async {
    final database = await db.database;
    await database.transaction((txn) async {
      for (final table in [
        'recurring_transactions',
        'budgets',
        'daily_performance_cache',
        'transaction_revisions',
        'goal_contributions',
        'transactions',
        'goals',
        'accounts',
        'journal_entries',
        'user_achievements',
        'streaks',
        'settings',
      ]) {
        await txn.delete(table);
      }
      await _insertDemo(txn);
    });
    await _recomputeDemo();
  }

  Future<void> run() => reseed();

  Future<void> _insertDemo(DatabaseExecutor database) async {
    final now = DateTime.now();

    // -- Settings --
    const settings = SettingsRecord(
      displayName: 'Kyle',
      cutoffHour: 3,
      currency: 'PHP',
    );
    await database.insert('settings', settings.toRow());

    // -- Accounts --
    final accounts = [
      AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 8200,
        color: '#22C55E',
        sortOrder: 0,
      ),
      AccountRecord(
        name: 'BPI Savings',
        type: 'bank',
        balance: 38480,
        color: '#3B82F6',
        sortOrder: 1,
      ),
      AccountRecord(
        name: 'GCash',
        type: 'ewallet',
        balance: 5800,
        color: '#A855F7',
        sortOrder: 2,
      ),
    ];
    for (final a in accounts) {
      await database.insert('accounts', a.toRow()..remove('id'));
    }

    // -- Goals (matching design screenshots) --
    final goals = [
      GoalRecord(
        name: 'Emergency Fund',
        kind: GoalKind.emergency,
        icon: 'shield',
        targetAmount: 50000,
        currentAmount: 32500,
        monthlyTarget: 4000,
        startedAt: now.subtract(const Duration(days: 120)),
        status: GoalStatus.active,
        sortOrder: 0,
      ),
      GoalRecord(
        name: 'Gaming PC',
        kind: GoalKind.gaming,
        icon: 'sports_esports',
        targetAmount: 50000,
        currentAmount: 16000,
        monthlyTarget: 3000,
        startedAt: now.subtract(const Duration(days: 90)),
        status: GoalStatus.active,
        sortOrder: 1,
      ),
      GoalRecord(
        name: 'Japan Trip',
        kind: GoalKind.travel,
        icon: 'flight',
        targetAmount: 50000,
        currentAmount: 9000,
        startedAt: now.subtract(const Duration(days: 60)),
        status: GoalStatus.active,
        sortOrder: 2,
      ),
    ];
    for (final g in goals) {
      await database.insert('goals', g.toRow()..remove('id'));
    }

    // -- Transactions for the last 30 days --
    final txs = _generateTransactions(now);
    for (final t in txs) {
      await database.insert('transactions', t.toRow()..remove('id'));
    }

    // -- Goal contributions backfilled to match currentAmount --
    // We approximate by adding a single historical contribution per goal.
    final goalsBack = await database.query('goals');
    for (final row in goalsBack) {
      final id = row['id'] as int;
      final current = (row['current_amount'] as num).toDouble();
      await database.insert('goal_contributions', {
        'goal_id': id,
        'amount': current,
        'contributed_at': now.toIso8601String(),
        'notes': 'Initial allocation (seeded)',
      });
    }

    // -- Journal entries (2) --
    final journal = [
      JournalRecord(
        entryDate: now.subtract(const Duration(days: 3)),
        mood: 'good',
        title: 'Good week! Stayed within budget and saved more.',
        content:
            'Stayed within budget and saved more than usual. Cooked meals at home most days.',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      JournalRecord(
        entryDate: now.subtract(const Duration(days: 10)),
        mood: 'stress',
        title: 'Unexpected laptop repair',
        content:
            'Spent ₱1,500 on an unexpected laptop repair. Need a larger emergency fund.',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
    ];
    for (final j in journal) {
      await database.insert('journal_entries', j.toRow()..remove('id'));
    }

    // -- Achievement definitions (seed) --
    // We persist only the id+name+description; icon/color live in the constants.
    await _seedAchievementDefs(database);

    // -- Streaks: pre-seed saving=12, logging=30 --
    final today = FinancialDay.today();
    await database.insert('streaks', {
      'id': 'saving',
      'current_count': 12,
      'best_count': 18,
      'last_qualified_day': DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String(),
    });
    await database.insert('streaks', {
      'id': 'logging',
      'current_count': 30,
      'best_count': 30,
      'last_qualified_day': DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String(),
    });
    await database.insert('streaks', {
      'id': 'goal',
      'current_count': 8,
      'best_count': 12,
      'last_qualified_day': DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String(),
    });
  }

  Future<void> _recomputeDemo() async {
    final now = DateTime.now();
    // Rebuild derived data after the source data commits.
    final repos = _buildRepos();
    final svc = RecalculationService(
      tx: repos.$1,
      cache: repos.$2,
      streaks: repos.$3,
      goals: repos.$4,
      achievements: repos.$5,
      accounts: repos.$6,
    );
    await svc.recomputeAll(cutoffHour: 3);

    // Award a couple of starter achievements so the Achievements screen isn't empty.
    final achievementRepo = AchievementRepo(db);
    for (final id in const ['first_1k', 'saving_streak_7']) {
      if (!(await achievementRepo.has(id))) {
        await achievementRepo.award(id, now.subtract(const Duration(days: 5)));
      }
    }
  }

  Future<void> _seedAchievementDefs(DatabaseExecutor database) async {
    // Persist every code-defined achievement into `achievement_definitions`
    // so the `user_achievements.achievement_id` FK has a valid target.
    // `REPLACE` keeps seeding idempotent across resets.
    for (final def in AchievementDefs.all) {
      await database.insert('achievement_definitions', {
        'id': def.id,
        'name': def.name,
        'description': def.description,
        'icon_code': def.icon.codePoint,
        'color_value': def.color.toARGB32(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Build repos for the recalc service.
  (
    TransactionRepo,
    CacheRepo,
    StreakRepo,
    GoalRepo,
    AchievementRepo,
    AccountRepo,
  )
  _buildRepos() {
    return (
      TransactionRepo(db),
      CacheRepo(db),
      StreakRepo(db),
      GoalRepo(db),
      AchievementRepo(db),
      AccountRepo(db),
    );
  }

  // --- Transaction generator ---
  // Creates a believable 30-day window that produces the calendar status mix
  // shown in the design: dark_green, green, yellow, red, dark_red tiles.
  List<TxRecord> _generateTransactions(DateTime now) {
    final out = <TxRecord>[];
    final rnd = math.Random(42); // deterministic seed

    // Salary every 15 days at 9 AM, ₱15,000
    for (int d = 0; d < 30; d++) {
      if (d == 5 || d == 20) {
        final day = DateTime(now.year, now.month, now.day - d, 9, 0);
        out.add(
          TxRecord(
            amount: 15000,
            type: TxType.income,
            category: 'salary',
            account: 'BPI Savings',
            occurredAt: day,
            notes: 'Bi-weekly salary',
            createdAt: day,
            updatedAt: day,
          ),
        );
      }
    }

    // Allowance top-up once
    out.add(
      TxRecord(
        amount: 2000,
        type: TxType.income,
        category: 'allowance',
        account: 'GCash',
        occurredAt: now.subtract(const Duration(days: 14, hours: 6)),
        notes: 'Monthly allowance',
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now.subtract(const Duration(days: 14)),
      ),
    );

    // Expense pattern per day. Each day has 0-3 expense entries.
    final expenseRecipes = <_ExpenseRecipe>[
      _ExpenseRecipe('food_dining', 'Jollibee', [
        120,
        150,
        180,
        220,
        250,
        320,
      ], 0.35),
      _ExpenseRecipe('food_dining', 'McDonald\'s', [180, 220, 250], 0.18),
      _ExpenseRecipe('food_dining', 'Starbucks', [180, 220, 260], 0.20),
      _ExpenseRecipe('food_dining', 'Lunch', [120, 150, 180], 0.30),
      _ExpenseRecipe('transportation', 'Grab', [120, 150, 180, 220, 250], 0.40),
      _ExpenseRecipe('transportation', 'Jeepney', [40, 50, 60], 0.30),
      _ExpenseRecipe('transportation', 'Gas', [400, 500, 600], 0.10),
      _ExpenseRecipe('groceries', 'Groceries', [350, 450, 550, 650], 0.18),
      _ExpenseRecipe('shopping', 'Shopee', [200, 350, 500, 800], 0.12),
      _ExpenseRecipe('shopping', 'Uniqlo', [800, 1200], 0.05),
      _ExpenseRecipe('bills', 'Electric bill', [1200, 1500], 0.05),
      _ExpenseRecipe('bills', 'Internet', [1500], 0.03),
      _ExpenseRecipe('bills', 'Netflix', [549], 0.05),
      _ExpenseRecipe('entertainment', 'Cinema', [350, 450], 0.08),
      _ExpenseRecipe('subscriptions', 'Spotify', [129], 0.05),
      _ExpenseRecipe('health', 'Pharmacy', [200, 350], 0.05),
      _ExpenseRecipe('education', 'Books', [350, 600], 0.04),
      _ExpenseRecipe('food_dining', 'Dinner', [200, 350, 500], 0.25),
      _ExpenseRecipe('food_dining', 'Snacks', [60, 100, 150], 0.25),
      _ExpenseRecipe('shopping', 'Lazada', [250, 450, 750], 0.10),
      _ExpenseRecipe('transportation', 'Toll fees', [80, 120], 0.10),
      // Heavy overspend day — single big purchase
      _ExpenseRecipe('shopping', 'Laptop repair', [1500], 0.01),
    ];

    for (int d = 0; d < 30; d++) {
      final today = DateTime(now.year, now.month, now.day - d);
      // Determine number of expenses today (0–4)
      final roll = rnd.nextDouble();
      int n;
      if (roll < 0.10) {
        n = 0; // ~10% pure saving days
      } else if (roll < 0.40) {
        n = 1;
      } else if (roll < 0.75) {
        n = 2;
      } else if (roll < 0.95) {
        n = 3;
      } else {
        n = 4;
      }

      // Force one "heavy overspending" day in the last 30 days
      bool heavyDay = false;
      if (d == 18) {
        n = 4;
        heavyDay = true;
      }

      for (int i = 0; i < n; i++) {
        final recipe = expenseRecipes[rnd.nextInt(expenseRecipes.length)];
        if (rnd.nextDouble() > recipe.frequency) continue;
        final amount = recipe.amounts[rnd.nextInt(recipe.amounts.length)];
        final hour = 7 + rnd.nextInt(15);
        final minute = rnd.nextInt(60);
        out.add(
          TxRecord(
            amount: amount.toDouble(),
            type: TxType.expense,
            category: recipe.category,
            account: _pickAccount(rnd),
            occurredAt: DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
            ),
            notes: recipe.note,
            createdAt: DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
            ),
            updatedAt: DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
            ),
          ),
        );
      }

      // Force a heavy day: add a 1500-2000 lump on top
      if (heavyDay) {
        out.add(
          TxRecord(
            amount: 1850,
            type: TxType.expense,
            category: 'shopping',
            account: 'BPI Savings',
            occurredAt: DateTime(today.year, today.month, today.day, 14, 30),
            notes: 'Laptop repair',
            createdAt: DateTime(today.year, today.month, today.day, 14, 30),
            updatedAt: DateTime(today.year, today.month, today.day, 14, 30),
          ),
        );
      }
    }

    return out;
  }

  String _pickAccount(math.Random rnd) {
    final pick = rnd.nextDouble();
    if (pick < 0.4) return 'Cash';
    if (pick < 0.85) return 'GCash';
    return 'BPI Savings';
  }
}

class _ExpenseRecipe {
  final String category;
  final String note;
  final List<int> amounts;
  final double frequency; // 0..1 chance per (day, attempt)
  _ExpenseRecipe(this.category, this.note, this.amounts, this.frequency);
}
