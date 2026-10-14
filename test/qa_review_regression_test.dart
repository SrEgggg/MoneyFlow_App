import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/services/backup_service.dart';
import 'package:savings_app/data/services/recalculation_service.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/providers.dart';
import 'package:savings_app/features/accounts/money_movement_dialog.dart';
import 'package:savings_app/features/transactions/widgets/transaction_list.dart';
import 'package:savings_app/data/services/backup_files.dart';
import 'package:savings_app/features/settings/settings_screen.dart';
import 'package:savings_app/app/router.dart';
import 'package:savings_app/app/theme.dart';

class TestBackupFiles extends BackupFiles {
  SelectedBackup? selection;
  String? exported;
  @override
  Future<bool> save(String json) async {
    exported = json;
    return true;
  }

  @override
  Future<SelectedBackup?> pick() async => selection;
}

class FailingRecalc extends RecalculationService {
  FailingRecalc(AppDatabase db)
    : super(
        tx: TransactionRepo(db),
        cache: CacheRepo(db),
        streaks: StreakRepo(db),
        goals: GoalRepo(db),
        achievements: AchievementRepo(db),
        accounts: AccountRepo(db),
      );
  @override
  Future<void> recomputeAll({int cutoffHour = 3}) async =>
      throw StateError('Injected cache failure after commit');
}

class FailingAccountsRefresh extends AccountsNotifier {
  @override
  Future<void> refresh() async =>
      throw StateError('Injected display refresh failure');
}

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 27, 12);
  const cash = AccountRecord(
    name: 'Cash',
    type: 'cash',
    balance: 1000,
    color: '#22C55E',
  );
  TxRecord tx() => TxRecord(
    amount: 10,
    type: TxType.expense,
    category: 'food_dining',
    account: 'Cash',
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
    notes: 'private note',
    tags: 'tag',
  );
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    await AccountRepo(db).insert(cash);
  });
  tearDown(() => db.close());
  test(
    'saved transaction retains a display-refresh warning after analytics succeed',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          accountsProvider.overrideWith(FailingAccountsRefresh.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(databaseProvider.future);
      await container.read(transactionsProvider.future);
      await container.read(transactionsProvider.notifier).add(tx());
      expect((await TransactionRepo(db).all()).length, 1);
      expect(await AccountRepo(db).totalBalance(), 990);
      expect(
        container.read(derivedDataIssueProvider),
        contains('reload totals'),
      );
    },
  );
  Future<void> settle(WidgetTester tester) async {
    // A confirmation intentionally leaves its underlying backup action busy.
    // Pump bounded frames rather than waiting for that progress animation to stop.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> ready(
    WidgetTester tester, {
    TestBackupFiles? files,
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        if (files != null) backupFilesProvider.overrideWithValue(files),
      ],
    );
    await tester.runAsync(() async {
      await container.read(firstRunProvider.future);
      await container.read(settingsProvider.future);
      await container.read(accountsProvider.future);
    });
    return container;
  }

  testWidgets(
    'backup picker cancellation and restore confirmation preserve data',
    (tester) async {
      final files = TestBackupFiles();
      final container = await ready(tester, files: files);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Restore'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Restore'));
      await settle(tester);
      expect(find.text('Replace data with this backup?'), findsNothing);
      expect(await tester.runAsync(() => AccountRepo(db).totalBalance()), 1000);
      final raw = await tester.runAsync(
        () => BackupService(db).exportJsonString(),
      );
      files.selection = SelectedBackup('my-backup.json', raw!);
      await tester.tap(find.text('Restore'));
      await settle(tester);
      expect(find.text('Replace data with this backup?'), findsOneWidget);
      expect(find.textContaining('my-backup.json'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      expect(await tester.runAsync(() => AccountRepo(db).totalBalance()), 1000);
      await tester.tap(find.text('Export'));
      await settle(tester);
      expect(jsonDecode(files.exported!)['tables']['accounts'].length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'Performance menu restores Journal and Monthly Reviews navigation',
    (tester) async {
      final container = await ready(tester);
      final router = buildRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      router.go(Routes.performance);
      await settle(tester);
      await tester.tap(find.byTooltip('Performance tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Journal'));
      await settle(tester);
      expect(find.text('Save Entry'), findsOneWidget);
      router.pop();
      await settle(tester);
      await tester.tap(find.byTooltip('Performance tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly reviews'));
      await settle(tester);
      expect(find.text('Monthly reviews'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      router.dispose();
      await tester.pump();
    },
  );
  test(
    'legacy duplicate migration keeps every account and original history',
    () async {
      final sql = await db.database;
      await sql.execute('DROP TRIGGER account_unique_insert');
      await sql.execute('DROP TRIGGER account_unique_rename');
      await TransactionRepo(db).insert(tx());
      await sql.insert('accounts', cash.toRow());
      await db.upgradeForTesting(6);
      final accounts = await AccountRepo(db).all();
      expect(accounts.length, 2);
      expect(await AccountRepo(db).totalBalance(), 1990);
      await AccountRepo(db).update(
        AccountRecord(
          id: accounts.last.id,
          name: 'Cash wallet',
          type: 'cash',
          balance: 1000,
          color: '#22C55E',
        ),
      );
      expect((await TransactionRepo(db).all()).single.account, 'Cash');
      await expectLater(AccountRepo(db).insert(cash), throwsA(anything));
    },
  );
  test('stale account rename preserves money recorded while editing', () async {
    final account = (await AccountRepo(db).all()).single;
    await TransactionRepo(db).insert(tx());
    await AccountRepo(db).update(
      AccountRecord(
        id: account.id,
        name: 'Wallet',
        type: 'cash',
        balance: account.balance,
        color: account.color,
      ),
      expectedBalance: account.balance,
    );
    expect(await AccountRepo(db).totalBalance(), 990);
    expect((await TransactionRepo(db).all()).single.account, 'Wallet');
  });
  test(
    'transaction revision and edit are atomic and included in backup',
    () async {
      final repo = TransactionRepo(db);
      final id = await repo.insert(tx());
      await expectLater(
        repo.update(tx().copyWith(id: id, account: 'Missing')),
        throwsStateError,
      );
      expect(await (await db.database).query('transaction_revisions'), isEmpty);
      await repo.update(
        tx().copyWith(id: id, notes: null, tags: null, amount: 20),
      );
      expect((await repo.all()).single.notes, isNull);
      final service = BackupService(db);
      final json = await service.exportJsonString();
      await service.restoreFromJsonString(json);
      expect(
        (await (await db.database).query('transaction_revisions')).length,
        1,
      );
      expect((await repo.all()).single.tags, isNull);
      expect(await AccountRepo(db).totalBalance(), 980);
      final legacy = jsonDecode(json) as Map<String, dynamic>;
      legacy['format'] = 6;
      legacy['tables'].remove('transaction_revisions');
      await service.restoreFromJsonString(jsonEncode(legacy));
      expect(await (await db.database).query('transaction_revisions'), isEmpty);
    },
  );
  test(
    'duplicate IDs and invalid settings reject replacement atomically',
    () async {
      final service = BackupService(db);
      final original = await service.exportJsonString();
      final data = jsonDecode(original) as Map<String, dynamic>;
      data['tables']['accounts'].add(data['tables']['accounts'][0]);
      await expectLater(
        service.restoreFromJsonString(jsonEncode(data)),
        throwsFormatException,
      );
      expect(await AccountRepo(db).totalBalance(), 1000);
      final settings = jsonDecode(original) as Map<String, dynamic>;
      settings['tables']['settings'][0]['currency'] = 'INVALID';
      await expectLater(
        service.restoreFromJsonString(jsonEncode(settings)),
        throwsFormatException,
      );
      expect((await SettingsRepo(db).load()).currency, 'PHP');
    },
  );
  test(
    'duplicate account insert is rejected; ordinary expense still works',
    () async {
      await expectLater(AccountRepo(db).insert(cash), throwsA(anything));
      expect((await AccountRepo(db).all()).length, 1);
      await TransactionRepo(db).insert(tx());
      expect(await AccountRepo(db).totalBalance(), 990);
    },
  );
  testWidgets('legacy duplicate account names show a helpful message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MoneyMovementDialog(accounts: [cash, cash])),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Review your accounts'), findsOneWidget);
  });
  test('decimal goal completes and permits exact withdrawal', () async {
    final repo = GoalRepo(db);
    final id = await repo.insert(
      GoalRecord(
        name: 'Small goal',
        kind: GoalKind.custom,
        icon: 'custom',
        targetAmount: .8,
        currentAmount: 0,
        startedAt: now,
        status: GoalStatus.active,
      ),
    );
    for (final amount in [.1, .7]) {
      await repo.addContribution(
        GoalContribution(goalId: id, amount: amount, contributedAt: now),
      );
    }
    final goal = (await repo.all()).single;
    expect(goal.currentAmount, .8);
    expect(goal.status, GoalStatus.completed);
    await repo.withdraw(id, .8);
    expect((await repo.all()).single.currentAmount, 0);
  });
  test('blank edit clears notes and tags', () {
    final edited = tx().copyWith(notes: null, tags: null);
    expect(edited.notes, isNull);
    expect(edited.tags, isNull);
  });
  test('oversized account balance is rejected', () async {
    final repo = AccountRepo(db);
    final account = (await repo.all()).single;
    await expectLater(
      repo.update(
        AccountRecord(
          id: account.id,
          name: 'Cash',
          type: 'cash',
          balance: 1e18,
          color: '#22C55E',
        ),
      ),
      throwsArgumentError,
    );
    await TransactionRepo(db).insert(tx().copyWith(type: TxType.income));
    expect((await TransactionRepo(db).all()).single.amount, 10);
    expect(await repo.totalBalance(), 1010);
  });
  test('sub-cent goal target is rejected', () async {
    await expectLater(
      GoalRepo(db).insert(
        GoalRecord(
          name: 'Fractional',
          kind: GoalKind.custom,
          icon: 'custom',
          targetAmount: .001,
          currentAmount: 0,
          startedAt: now,
          status: GoalStatus.active,
        ),
      ),
      throwsArgumentError,
    );
  });
  testWidgets('destination account search finds the transfer', (tester) async {
    final transfer = tx().copyWith(
      type: TxType.transfer,
      destinationAccount: 'GCash',
      category: 'transfer',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionList(txs: [transfer], onTap: (_) {}),
        ),
      ),
    );
    expect(find.text('No transactions match your filters'), findsNothing);
    await tester.enterText(find.byType(TextField), 'GCash');
    await tester.pumpAndSettle();
    expect(find.text('No transactions match your filters'), findsNothing);
  });
  test(
    'restore rejects invalid transaction amount/date without changes',
    () async {
      await TransactionRepo(db).insert(tx());
      final svc = BackupService(db);
      final data =
          jsonDecode(await svc.exportJsonString()) as Map<String, dynamic>;
      data['tables']['transactions'][0]['amount'] = -500;
      data['tables']['transactions'][0]['occurred_at'] = 'not-a-date';
      await expectLater(
        svc.restoreFromJsonString(jsonEncode(data)),
        throwsFormatException,
      );
      expect((await TransactionRepo(db).all()).single.amount, 10);
      expect(await AccountRepo(db).totalBalance(), 990);
    },
  );
  test('incomplete current backup preserves journal', () async {
    await (await db.database).insert('journal_entries', {
      'entry_date': now.toIso8601String(),
      'mood': 'happy',
      'content': 'Keep me',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    final svc = BackupService(db);
    final data =
        jsonDecode(await svc.exportJsonString()) as Map<String, dynamic>;
    data['tables'].remove('journal_entries');
    await expectLater(
      svc.restoreFromJsonString(jsonEncode(data)),
      throwsFormatException,
    );
    expect((await (await db.database).query('journal_entries')).length, 1);
  });
  test(
    'post-commit failure keeps success and retry reuses the saved entry',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          recalcServiceProvider.overrideWithValue(FailingRecalc(db)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(databaseProvider.future);
      await container.read(transactionsProvider.future);
      final request = tx();
      final id = await container
          .read(transactionsProvider.notifier)
          .add(request);
      expect(
        await container.read(transactionsProvider.notifier).add(request),
        id,
      );
      expect((await TransactionRepo(db).all()).length, 1);
      expect(await AccountRepo(db).totalBalance(), 990);
      expect(container.read(derivedDataIssueProvider), isNotNull);
    },
  );
  test('changing financial cutoff refreshes cached daily totals', () async {
    await TransactionRepo(
      db,
    ).insert(tx().copyWith(occurredAt: DateTime(2026, 9, 26, 2)));
    final recalc = RecalculationService(
      tx: TransactionRepo(db),
      cache: CacheRepo(db),
      streaks: StreakRepo(db),
      goals: GoalRepo(db),
      achievements: AchievementRepo(db),
      accounts: AccountRepo(db),
    );
    await recalc.recomputeAll(cutoffHour: 3);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);
    await container.read(databaseProvider.future);
    final settings = await container.read(settingsProvider.future);
    await container
        .read(settingsProvider.notifier)
        .save(settings.copyWith(cutoffHour: 0));
    expect((await CacheRepo(db).all()).single.date, DateTime(2026, 9, 26));
    await recalc.recomputeAll(cutoffHour: 0);
    expect((await CacheRepo(db).all()).single.date, DateTime(2026, 9, 26));
  });
}
