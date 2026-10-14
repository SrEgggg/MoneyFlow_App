import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for MoneyFlow.
///
/// Dates are stored as ISO-8601 strings. Financial-day calculations apply
/// the configured cutoff separately from calendar-date summaries.
///
/// Schema versions:
///   v1: original schema (accounts, transactions, goals, journal, etc.)
///   v2: adds `budgets` (per-category caps), `recurring_transactions`
///       (recurring rules), and a search-friendly index on transactions.
class AppDatabase {
  AppDatabase._();
  AppDatabase.forTesting(Database database) : _db = database;
  Future<void> createSchemaForTesting() async =>
      _create(await database, currentVersion);
  static final AppDatabase instance = AppDatabase._();

  /// Bump this whenever the schema changes. Each bump MUST add an entry to
  /// [_onUpgrade] below.
  Future<void> upgradeForTesting(int oldVersion) async =>
      _onUpgrade(await database, oldVersion, currentVersion);

  static const int currentVersion = 7;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'moneyflow.db');
    return openDatabase(
      path,
      version: currentVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    final batch = db.batch();

    // Settings (single-row)
    batch.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        display_name TEXT NOT NULL,
        cutoff_hour INTEGER NOT NULL DEFAULT 3,
        currency TEXT NOT NULL DEFAULT 'PHP',
        theme_mode TEXT NOT NULL DEFAULT 'system'
      )
    ''');

    // Accounts
    batch.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Transactions
    batch.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        account TEXT NOT NULL,
        destination_account TEXT,
        occurred_at TEXT NOT NULL,
        notes TEXT,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_tx_occurred_at ON transactions(occurred_at)',
    );
    batch.execute('CREATE INDEX idx_tx_category ON transactions(category)');
    batch.execute('CREATE INDEX idx_tx_account ON transactions(account)');

    // Goals
    batch.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL,
        monthly_target REAL,
        started_at TEXT NOT NULL,
        target_date TEXT,
        status TEXT NOT NULL,
        completed_at TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        photo TEXT
      )
    ''');

    // Goal contributions (append-only)
    batch.execute('''
      CREATE TABLE goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        contributed_at TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
      )
    ''');

    // Daily performance cache
    batch.execute('''
      CREATE TABLE daily_performance_cache (
        date TEXT PRIMARY KEY,
        income REAL NOT NULL DEFAULT 0,
        expenses REAL NOT NULL DEFAULT 0,
        saved_amount REAL NOT NULL DEFAULT 0,
        allowance REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'green',
        notes TEXT,
        computed_at TEXT NOT NULL
      )
    ''');

    // Journal entries
    batch.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL,
        mood TEXT NOT NULL,
        title TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_journal_entry_date ON journal_entries(entry_date)',
    );

    // Achievement definitions (seeded)
    batch.execute('''
      CREATE TABLE achievement_definitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
 is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User achievements
    batch.execute('''
      CREATE TABLE user_achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achievement_id TEXT NOT NULL,
        earned_at TEXT NOT NULL,
        FOREIGN KEY (achievement_id) REFERENCES achievement_definitions(id)
          ON DELETE CASCADE
      )
    ''');

    // Streaks
    batch.execute('''
      CREATE TABLE streaks (
        id TEXT PRIMARY KEY,
        current_count INTEGER NOT NULL DEFAULT 0,
        best_count INTEGER NOT NULL DEFAULT 0,
        last_qualified_day TEXT
      )
    ''');

    // Transaction revisions (audit trail)
    batch.execute('''
      CREATE TABLE transaction_revisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        old_values TEXT NOT NULL,
        new_values TEXT NOT NULL,
        changed_at TEXT NOT NULL
      )
    ''');

    // v2: Budgets — per-category caps with optional month.
    // `month_key` is null = applies to the current month (rolling); a value
    // like '2026-08' pins it to that calendar month.
    batch.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        month_key TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_budgets_category ON budgets(category)');

    // v2: Recurring transactions — rules that materialize real transactions.
    // `frequency` is one of: daily, weekly, monthly.
    // `interval_count` is "every N <unit>" (e.g. 2 + weekly = every 2 weeks).
    // `next_run_at` is the cutoff-aware ISO timestamp of the next occurrence.
    batch.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        account TEXT NOT NULL,
        frequency TEXT NOT NULL,
        interval_count INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_run_at TEXT NOT NULL,
        last_run_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_recurring_next_run ON recurring_transactions(next_run_at)',
    );

    batch.execute(customCategoriesSchema);
    await batch.commit(noResult: true);
    await _accountNameGuards(db);
  }

  /// Migrate an older database forward to [currentVersion]. Always
  /// idempotent: re-running on an already-migrated DB must be a no-op.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Budgets table.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          month_key TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category)',
      );

      // Recurring transactions table.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          account TEXT NOT NULL,
          frequency TEXT NOT NULL,
          interval_count INTEGER NOT NULL DEFAULT 1,
          start_date TEXT NOT NULL,
          end_date TEXT,
          next_run_at TEXT NOT NULL,
          last_run_at TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recurring_next_run '
        'ON recurring_transactions(next_run_at)',
      );

      // Account index is useful for backup/export and filter-by-account.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account)',
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
      );
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN destination_account TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(customCategoriesSchema);
    }
    if (oldVersion == 4) {
      await db.execute(
        'ALTER TABLE custom_categories ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      final columns = await db.rawQuery('PRAGMA table_info(goals)');
      if (columns.isNotEmpty && !columns.any((c) => c['name'] == 'photo')) {
        await db.execute('ALTER TABLE goals ADD COLUMN photo TEXT');
      }
    }
    if (oldVersion < 7) {
      await _accountNameGuards(db);
      final goals = await db.rawQuery('PRAGMA table_info(goals)');
      if (goals.isNotEmpty) {
        // Correct binary floating-point residue only, not intentional legacy
        // sub-cent values. No records or contributions are removed.
        await db.execute(
          'UPDATE goals SET current_amount = ROUND(current_amount, 2) WHERE ABS(current_amount - ROUND(current_amount, 2)) < 0.0000001',
        );
        await db.execute(
          "UPDATE goals SET status = 'completed' WHERE current_amount >= target_amount AND target_amount > 0 AND status != 'archived'",
        );
      }
    }
    // Future versions: `if (oldVersion < 3) { ... }`
  }

  Future<void> _accountNameGuards(Database db) async {
    if ((await db.rawQuery('PRAGMA table_info(accounts)')).isEmpty) return;
    // Triggers preserve legacy duplicates for explicit user reconciliation.
    // Unlike building a unique index, installing these never drops/merges data.
    await db.execute('''CREATE TRIGGER IF NOT EXISTS account_unique_insert
      BEFORE INSERT ON accounts WHEN EXISTS
      (SELECT 1 FROM accounts WHERE lower(trim(name)) = lower(trim(NEW.name)))
      BEGIN SELECT RAISE(ABORT, 'Account names must be unique'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS account_unique_rename
      BEFORE UPDATE OF name ON accounts WHEN NEW.name != OLD.name AND EXISTS
      (SELECT 1 FROM accounts WHERE id != OLD.id AND lower(trim(name)) = lower(trim(NEW.name)))
      BEGIN SELECT RAISE(ABORT, 'Account names must be unique'); END''');
  }

  /// Wipe all data tables (for "Reset demo data" button). User-data tables
  /// only — schema and definitions are left intact.
  Future<void> wipe() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = [
        'custom_categories',
        'recurring_transactions',
        'budgets',
        'transaction_revisions',
        'user_achievements',
        'streaks',
        'journal_entries',
        'daily_performance_cache',
        'goal_contributions',
        'goals',
        'transactions',
        'accounts',
        'settings',
        // Don't drop achievement_definitions — keep definitions, just wipe
        // user_achievements above.
      ];
      for (final t in tables) {
        await txn.delete(t);
      }
      await txn.insert('settings', {
        'id': 1,
        'display_name': 'there',
        'cutoff_hour': 3,
        'currency': 'PHP',
      });
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

const customCategoriesSchema = '''
CREATE TABLE IF NOT EXISTS custom_categories (
 id TEXT PRIMARY KEY,
 name TEXT NOT NULL,
 normalized_name TEXT NOT NULL UNIQUE,
 kind TEXT NOT NULL CHECK(kind IN ('income', 'expense')),
 icon_key TEXT NOT NULL,
 color_value INTEGER NOT NULL,
 is_archived INTEGER NOT NULL DEFAULT 0
)
''';
