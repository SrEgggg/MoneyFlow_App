import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/budget.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/repositories/recurring_repository.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/services/backup_service.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/providers.dart';

void main() {
  late AppDatabase db;
  late AccountRepo accounts;
  late TransactionRepo tx;
  late RecurringRepo recurring;
  late RecurringRunner runner;
  final now = DateTime(2026, 9, 14, 12);
  RecurringTransactionRecord rule({
    DateTime? start,
    DateTime? end,
    RecurringFrequency frequency = RecurringFrequency.daily,
    int interval = 1,
    String account = 'Cash',
    TxType type = TxType.income,
  }) {
    final date = start ?? DateTime(2026, 9, 12, 10);
    return RecurringTransactionRecord(
      name: 'Allowance',
      amount: 125.25,
      type: type,
      category: type == TxType.income ? 'allowance' : 'food_dining',
      account: account,
      frequency: frequency,
      intervalCount: interval,
      startDate: date,
      endDate: end,
      nextRunAt: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    accounts = AccountRepo(db);
    tx = TransactionRepo(db);
    recurring = RecurringRepo(db);
    runner = RecurringRunner(recurring: recurring, tx: tx);
    await accounts.insert(
      const AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 1000,
        color: '#22C55E',
      ),
    );
  });
  tearDown(() => db.close());

  test(
    'catches up every due date and retry/recreated runner cannot duplicate',
    () async {
      await recurring.insert(rule());
      expect(await runner.materializeDue(now: now), 3);
      expect(await accounts.totalBalance(), 1375.75);
      final records = await tx.all();
      expect(records.map((r) => r.occurredAt.day).toList(), [14, 13, 12]);
      final saved = (await recurring.all()).single;
      expect(saved.nextRunAt, DateTime(2026, 9, 15, 10));
      expect(saved.lastRunAt, DateTime(2026, 9, 14, 10));
      final restarted = RecurringRunner(
        recurring: RecurringRepo(db),
        tx: TransactionRepo(db),
      );
      expect(await restarted.materializeDue(now: now), 0);
      expect(await accounts.totalBalance(), 1375.75);
    },
  );
  test(
    'concurrent runs serialize and only one posts each occurrence',
    () async {
      await recurring.insert(rule());
      final counts = await Future.wait([
        runner.materializeDue(now: now),
        RecurringRunner(
          recurring: RecurringRepo(db),
          tx: TransactionRepo(db),
        ).materializeDue(now: now),
      ]);
      expect(counts.reduce((a, b) => a + b), 3);
      expect((await tx.all()).length, 3);
      expect(await accounts.totalBalance(), 1375.75);
    },
  );
  test(
    'failure advancing rule rolls back inserted transactions and balances',
    () async {
      await recurring.insert(rule());
      await (await db.database).execute(
        "CREATE TRIGGER fail_advance BEFORE UPDATE ON recurring_transactions BEGIN SELECT RAISE(ABORT, 'simulated schedule write failure'); END",
      );
      await expectLater(
        runner.materializeDue(now: now),
        throwsA(isA<DatabaseException>()),
      );
      expect(await tx.all(), isEmpty);
      expect(await accounts.totalBalance(), 1000);
      expect(
        (await recurring.all()).single.nextRunAt,
        DateTime(2026, 9, 12, 10),
      );
      expect((await recurring.all()).single.lastRunAt, isNull);
      await (await db.database).execute('DROP TRIGGER fail_advance');
      expect(await runner.materializeDue(now: now), 3);
    },
  );
  test(
    'bad second rule rolls back the entire batch and can be repaired',
    () async {
      await recurring.insert(rule());
      final bad = await recurring.insert(rule(account: 'Missing'));
      await expectLater(runner.materializeDue(now: now), throwsStateError);
      expect(await tx.all(), isEmpty);
      expect(await accounts.totalBalance(), 1000);
      expect((await recurring.all()).every((r) => r.lastRunAt == null), isTrue);
      final broken = (await recurring.all()).firstWhere((r) => r.id == bad);
      await recurring.update(broken.copyWith(account: 'Cash'));
      expect(await runner.materializeDue(now: now), 6);
    },
  );
  test(
    'expired rule catches up through inclusive end date then deactivates',
    () async {
      await recurring.insert(rule(end: DateTime(2026, 9, 13)));
      expect(await runner.materializeDue(now: now), 2);
      expect((await tx.all()).map((r) => r.occurredAt.day), [13, 12]);
      final saved = (await recurring.all()).single;
      expect(saved.isActive, isFalse);
      expect(saved.nextRunAt, DateTime(2026, 9, 14, 10));
    },
  );
  test('monthly dates return to original day after short month', () async {
    await recurring.insert(
      rule(
        start: DateTime(2026, 1, 31, 10),
        frequency: RecurringFrequency.monthly,
      ),
    );
    expect(await runner.materializeDue(now: DateTime(2026, 3, 31, 12)), 3);
    expect((await tx.all()).map((r) => r.occurredAt).toList(), [
      DateTime(2026, 3, 31, 10),
      DateTime(2026, 2, 28, 10),
      DateTime(2026, 1, 31, 10),
    ]);
    final leap = rule(
      start: DateTime(2024, 1, 31),
      frequency: RecurringFrequency.monthly,
    );
    expect(leap.computeNextAfter(leap.startDate), DateTime(2024, 2, 29));
    expect(leap.computeNextAfter(DateTime(2024, 2, 29)), DateTime(2024, 3, 31));
  });
  test(
    'future and paused rules do not post; expense cadence deducts cents',
    () async {
      final pausedId = await recurring.insert(rule());
      await recurring.update(
        (await recurring.all()).single.copyWith(isActive: false),
      );
      await recurring.insert(rule(start: DateTime(2026, 9, 14, 13)));
      await recurring.insert(
        rule(
          start: DateTime(2026, 8, 31, 10),
          frequency: RecurringFrequency.weekly,
          interval: 2,
          type: TxType.expense,
        ),
      );
      expect(await runner.materializeDue(now: now), 2);
      expect(await accounts.totalBalance(), 749.5);
      expect(
        (await recurring.all()).firstWhere((r) => r.id == pausedId).lastRunAt,
        isNull,
      );
    },
  );
  test(
    'stale edit cannot rewind progress; cadence edit starts after last posting',
    () async {
      await recurring.insert(rule());
      final stale = (await recurring.all()).single;
      await runner.materializeDue(now: now);
      await recurring.update(stale.copyWith(name: 'Renamed'));
      expect(await runner.materializeDue(now: now), 0);
      await recurring.update(
        stale.copyWith(frequency: RecurringFrequency.weekly),
      );
      expect(
        (await recurring.all()).single.nextRunAt,
        DateTime(2026, 9, 19, 10),
      );
      expect(await runner.materializeDue(now: now), 0);
      expect((await tx.all()).length, 3);
    },
  );
  test(
    'deleting a posted transaction does not regenerate it on the next run',
    () async {
      await recurring.insert(rule());
      await runner.materializeDue(now: now);
      await tx.delete((await tx.all()).first.id!);
      expect(await runner.materializeDue(now: now), 0);
      expect((await tx.all()).length, 2);
      expect(await accounts.totalBalance(), 1250.5);
    },
  );
  test(
    'bounded batches continue without skipping or duplicating dates',
    () async {
      await recurring.insert(rule());
      expect(await recurring.postDue(tx, now, batchLimit: 2), 2);
      expect(await recurring.postDue(tx, now, batchLimit: 2), 1);
      expect(await recurring.postDue(tx, now, batchLimit: 2), 0);
      expect(await accounts.totalBalance(), 1375.75);
    },
  );
  test(
    'invalid cadence and amount rejected; nullable fields can be cleared',
    () async {
      await expectLater(
        recurring.insert(rule(interval: 0)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.insert(rule(interval: -1)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.insert(rule(interval: 121)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.insert(rule().copyWith(amount: double.infinity)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.insert(rule(end: DateTime(2026, 9, 11))),
        throwsArgumentError,
      );
      final original = rule(end: now).copyWith(notes: 'A note');
      expect(original.copyWith().endDate, now);
      expect(original.copyWith(endDate: null, notes: null).endDate, isNull);
      expect(original.copyWith(endDate: null, notes: null).notes, isNull);
    },
  );
  test('backup restore retains posting progress and does not repost', () async {
    await recurring.insert(rule());
    await runner.materializeDue(now: now);
    final backup = BackupService(db);
    await backup.restoreFromJsonString(await backup.exportJsonString());
    expect(await runner.materializeDue(now: now), 0);
    expect((await tx.all()).length, 3);
    expect(await accounts.totalBalance(), 1375.75);
  });
  test(
    'automatic posting failure leaves startup usable and shows recovery notice',
    () async {
      await recurring.insert(
        rule(
          account: 'Missing',
          start: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      await container.read(firstRunProvider.future);
      expect(container.read(recurringIssueProvider), contains('no changes'));
      expect(await tx.all(), isEmpty);
      expect(await accounts.totalBalance(), 1000);
      expect(await container.read(settingsProvider.future), isNotNull);
    },
  );
}
