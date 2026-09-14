import 'package:savings_app/data/services/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savings_app/main.dart';
import 'package:savings_app/features/performance/calendar_tab.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/data/services/recalculation_service.dart';

void main() {
  late AppDatabase db;
  late AccountRepo accounts;
  late TransactionRepo txs;
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    accounts = AccountRepo(db);
    txs = TransactionRepo(db);
    await accounts.insert(
      const AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 1000,
        color: '#22C55E',
        sortOrder: 0,
      ),
    );
  });
  tearDown(() => db.close());
  TxRecord record(
    double amount, {
    TxType type = TxType.expense,
    String account = 'Cash',
  }) {
    final now = DateTime.now();
    return TxRecord(
      amount: amount,
      type: type,
      category: 'food_dining',
      account: account,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  test(
    'goal contributions update progress atomically and deletion preserves cash',
    () async {
      final repo = GoalRepo(db);
      final now = DateTime.now();
      final id = await repo.insert(
        GoalRecord(
          name: 'Emergency',
          kind: GoalKind.emergency,
          icon: 'emergency',
          targetAmount: 100,
          currentAmount: 0,
          startedAt: now,
          status: GoalStatus.active,
        ),
      );
      await Future.wait([
        repo.addContribution(
          GoalContribution(goalId: id, amount: 30, contributedAt: now),
        ),
        repo.addContribution(
          GoalContribution(goalId: id, amount: 40, contributedAt: now),
        ),
      ]);
      expect((await repo.all()).single.currentAmount, 70);
      await expectLater(
        repo.addContribution(
          GoalContribution(goalId: id, amount: 40, contributedAt: now),
        ),
        throwsStateError,
      );
      expect((await repo.contributionsFor(id)).length, 2);
      await expectLater(
        repo.addContribution(
          GoalContribution(goalId: id, amount: double.nan, contributedAt: now),
        ),
        throwsArgumentError,
      );
      await txs.insert(record(10));
      await repo.delete(id);
      expect(await repo.allContributions(), isEmpty);
      expect((await txs.all()).length, 1);
      expect(await accounts.totalBalance(), 990);
    },
  );

  test(
    'backup roundtrip preserves contributions with foreign keys enabled',
    () async {
      await (await db.database).execute('PRAGMA foreign_keys = ON');
      final repo = GoalRepo(db);
      final now = DateTime.now();
      final id = await repo.insert(
        GoalRecord(
          name: 'Backup goal',
          kind: GoalKind.emergency,
          icon: 'emergency',
          targetAmount: 100,
          currentAmount: 0,
          startedAt: now,
          status: GoalStatus.active,
        ),
      );
      await repo.addContribution(
        GoalContribution(goalId: id, amount: 25, contributedAt: now),
      );
      final backup = BackupService(db);
      final json = await backup.exportJsonString();
      await backup.restoreFromJsonString(json);
      expect((await repo.all()).single.currentAmount, 25);
      expect((await repo.allContributions()).single.amount, 25);
      await expectLater(
        backup.restoreFromJsonString('{"format":2,"tables":{}}'),
        throwsFormatException,
      );
      expect((await repo.all()).single.currentAmount, 25);
      expect(await accounts.totalBalance(), 1000);
    },
  );

  testWidgets('calendar selects dates and stays usable on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await tester.runAsync(() => container.read(firstRunProvider.future));
    await tester.runAsync(() => container.read(goalsProvider.future));
    await tester.runAsync(() => container.read(activityProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: CalendarTab()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mon'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });

  testWidgets('navigation, profile save and empty name keep app visible', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await tester.runAsync(() => container.read(firstRunProvider.future));
    await tester.runAsync(() => container.read(settingsProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MoneyFlowApp(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Settings').last);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Display name'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Maria');
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Maria'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Display name'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Display name is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
  test('add, edit type and amount, delete keep balance correct', () async {
    final id = await txs.insert(record(125.25));
    expect(await accounts.totalBalance(), 874.75);
    final old = (await txs.byId(id))!;
    await txs.update(old.copyWith(amount: 50, type: TxType.income));
    expect(await accounts.totalBalance(), 1050);
    await txs.delete(id);
    expect(await accounts.totalBalance(), 1000);
    await txs.delete(id);
    expect(await accounts.totalBalance(), 1000);
  });
  test(
    'invalid account and amount roll back without changing balance',
    () async {
      await expectLater(
        txs.insert(record(20, account: 'Missing')),
        throwsStateError,
      );
      await expectLater(txs.insert(record(double.nan)), throwsArgumentError);
      expect(await txs.all(), isEmpty);
      expect(await accounts.totalBalance(), 1000);
    },
  );
  test('startup preserves profile and earned achievements', () async {
    await SettingsRepo(db).save(
      const SettingsRecord(
        displayName: 'Maria',
        cutoffHour: 4,
        currency: 'PHP',
      ),
    );
    await AchievementRepo(db).award('first_1k', DateTime.now());
    await FirstRunInitializer(db).ensureInitialized();
    expect((await SettingsRepo(db).load()).displayName, 'Maria');
    expect((await SettingsRepo(db).load()).cutoffHour, 4);
    expect(await AchievementRepo(db).has('first_1k'), isTrue);
  });
  test('clear and repeated demo reset return valid consistent data', () async {
    await SeedRunner(db).reseed();
    final count = (await txs.all()).length;
    await SeedRunner(db).reseed();
    expect((await txs.all()).length, count);
    expect((await accounts.all()).length, 3);
    expect((await SettingsRepo(db).load()).displayName, 'Kyle');
    await db.wipe();
    expect(await txs.all(), isEmpty);
    expect(await accounts.totalBalance(), 0);
    expect((await SettingsRepo(db).load()).displayName, 'there');
  });
  test('deleting final transaction removes stale daily statistics', () async {
    final svc = RecalculationService(
      tx: txs,
      cache: CacheRepo(db),
      streaks: StreakRepo(db),
      goals: GoalRepo(db),
      achievements: AchievementRepo(db),
      accounts: accounts,
    );
    final id = await txs.insert(record(100));
    await svc.recomputeAll();
    expect(await CacheRepo(db).all(), isNotEmpty);
    await txs.delete(id);
    await svc.recomputeAll();
    expect(await CacheRepo(db).all(), isEmpty);
  });
}
