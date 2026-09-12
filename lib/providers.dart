import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database/database.dart';
import 'data/models/budget.dart';
import 'data/models/models.dart';
import 'data/repositories/budget_repository.dart';
import 'data/repositories/recurring_repository.dart';
import 'data/repositories/repositories.dart';
import 'data/seed/seed_data.dart';
import 'data/services/backup_service.dart';
import 'data/services/recalculation_service.dart';
import 'core/utils/app_logger.dart';

/// Root providers. The app boots these on startup.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return AppDatabase.instance;
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger();
});

final settingsRepoProvider = Provider<SettingsRepo>((ref) {
  return SettingsRepo(ref.watch(databaseProvider).requireValue);
});

final accountRepoProvider = Provider<AccountRepo>((ref) {
  return AccountRepo(ref.watch(databaseProvider).requireValue);
});

final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  return TransactionRepo(ref.watch(databaseProvider).requireValue);
});

final goalRepoProvider = Provider<GoalRepo>((ref) {
  return GoalRepo(ref.watch(databaseProvider).requireValue);
});

final journalRepoProvider = Provider<JournalRepo>((ref) {
  return JournalRepo(ref.watch(databaseProvider).requireValue);
});

final cacheRepoProvider = Provider<CacheRepo>((ref) {
  return CacheRepo(ref.watch(databaseProvider).requireValue);
});

final streakRepoProvider = Provider<StreakRepo>((ref) {
  return StreakRepo(ref.watch(databaseProvider).requireValue);
});

final achievementRepoProvider = Provider<AchievementRepo>((ref) {
  return AchievementRepo(ref.watch(databaseProvider).requireValue);
});

final budgetRepoProvider = Provider<BudgetRepo>((ref) {
  return BudgetRepo(
    ref.watch(databaseProvider).requireValue,
    logger: ref.watch(appLoggerProvider),
  );
});

final recurringRepoProvider = Provider<RecurringRepo>((ref) {
  return RecurringRepo(
    ref.watch(databaseProvider).requireValue,
    logger: ref.watch(appLoggerProvider),
  );
});

/// Materializes due recurring transactions. Used by the bootstrap and after
/// writes that could push `nextRunAt` into the past.
final recurringRunnerProvider = Provider<RecurringRunner>((ref) {
  return RecurringRunner(
    recurring: ref.watch(recurringRepoProvider),
    tx: ref.watch(transactionRepoProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// Backup / restore service — reads/writes the local JSON dump.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider).requireValue,
    logger: ref.watch(appLoggerProvider),
  );
});

/// Settings value stream (rebuilds whenever settings change).
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsRecord>(
  SettingsNotifier.new,
);

/// Reactive list of all transactions.
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TxRecord>>(
  TransactionsNotifier.new,
);

/// Reactive list of all accounts.
final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<AccountRecord>>(
  AccountsNotifier.new,
);

/// Reactive list of goals.
final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<GoalRecord>>(
  GoalsNotifier.new,
);

/// Reactive list of journal entries.
final journalProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalRecord>>(
  JournalNotifier.new,
);

/// Reactive cache entries for a given month range.
final dailyCacheForMonthProvider = FutureProvider.family
    .autoDispose<List<DailyPerformance>, ({DateTime month, int cutoffHour})>(
  (ref, args) async {
    final repo = ref.watch(cacheRepoProvider);
    return repo.forMonth(args.month, cutoffHour: args.cutoffHour);
  },
);

/// Daily performance for one day.
final dailyCacheForDayProvider = FutureProvider.family
    .autoDispose<DailyPerformance?, ({DateTime date, int cutoffHour})>(
  (ref, args) async {
    final repo = ref.watch(cacheRepoProvider);
    return repo.forDay(args.date, cutoffHour: args.cutoffHour);
  },
);

/// All streak counters.
final streaksProvider = AsyncNotifierProvider<StreaksNotifier, List<StreakRecord>>(
  StreaksNotifier.new,
);

/// Earned achievements.
final earnedAchievementsProvider =
    AsyncNotifierProvider<EarnedAchievementsNotifier, List<EarnedAchievement>>(
  EarnedAchievementsNotifier.new,
);

/// Reactive list of budget rules.
final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<BudgetRecord>>(
  BudgetsNotifier.new,
);

/// Reactive list of recurring transaction rules.
final recurringProvider =
    AsyncNotifierProvider<RecurringNotifier, List<RecurringTransactionRecord>>(
  RecurringNotifier.new,
);

/// Recalculation service — used by transaction/goal writes to update cache.
final recalcServiceProvider = Provider<RecalculationService>((ref) {
  return RecalculationService(
    tx: ref.watch(transactionRepoProvider),
    cache: ref.watch(cacheRepoProvider),
    streaks: ref.watch(streakRepoProvider),
    goals: ref.watch(goalRepoProvider),
    achievements: ref.watch(achievementRepoProvider),
    accounts: ref.watch(accountRepoProvider),
  );
});

/// First-run initializer. Creates the default empty settings row so
/// downstream providers (which depend on a settings record existing) load
/// correctly, but does NOT seed any demo data. The user starts with a
/// completely empty state and adds their own accounts/goals/transactions.
///
/// Also materializes any due recurring transactions so the app feels live on
/// first open (e.g. a salary rule with `nextRunAt` in the past).
final firstRunProvider = FutureProvider<void>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await FirstRunInitializer(db).ensureInitialized();
  await ref.read(recurringRunnerProvider).materializeDue();
  final settings = await ref.read(settingsRepoProvider).load();
  await ref.read(recalcServiceProvider).recomputeAll(cutoffHour: settings.cutoffHour);
});