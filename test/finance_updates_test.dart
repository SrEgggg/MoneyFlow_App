import 'package:go_router/go_router.dart';
import 'package:savings_app/features/goals/create_goal_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:savings_app/features/home/providers/home_providers.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:savings_app/features/accounts/accounts_screen.dart';
import 'package:savings_app/features/goals/goal_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savings_app/providers.dart';
import 'package:savings_app/main.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/features/accounts/money_movement_dialog.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/core/utils/goal_plan.dart';
import 'package:savings_app/core/utils/activity_summary.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/data/services/backup_service.dart';

void main() {
  late AppDatabase db;
  late TransactionRepo tx;
  late AccountRepo accounts;
  final now = DateTime(2026, 9, 18, 12);
  GoalRecord goal({
    double target = 30000,
    double saved = 10000,
    DateTime? date,
  }) => GoalRecord(
    name: 'Emergency',
    kind: GoalKind.emergency,
    icon: 'emergency',
    targetAmount: target,
    currentAmount: saved,
    startedAt: now,
    targetDate: date,
    status: GoalStatus.active,
  );
  TxRecord movement(
    double amount,
    TxType type, {
    String from = 'Bank',
    String? to,
  }) => TxRecord(
    amount: amount,
    type: type,
    category: type == TxType.transfer ? 'transfer' : 'other_income',
    account: from,
    destinationAccount: to,
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
  );
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    accounts = AccountRepo(db);
    tx = TransactionRepo(db);
    await accounts.insert(
      const AccountRecord(
        name: 'Bank',
        type: 'bank',
        balance: 5000,
        color: '#22C55E',
      ),
    );
    await accounts.insert(
      const AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 100,
        color: '#22C55E',
      ),
    );
  });
  tearDown(() => db.close());
  testWidgets('create goal form saves a dated goal and returns safely', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await tester.runAsync(() => container.read(firstRunProvider.future));
    await tester.runAsync(() => container.read(goalsProvider.future));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Scaffold(
            body: TextButton(
              onPressed: () => c.push('/new'),
              child: const Text('New'),
            ),
          ),
        ),
        GoRoute(path: '/new', builder: (_, __) => const CreateGoalScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Travel fund');
    await tester.enterText(find.byType(TextField).at(1), '30000');
    await tester.scrollUntilVisible(
      find.text('No target date'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Goal'));
    await tester.tap(find.text('Create Goal'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final saved = (await GoalRepo(db).all()).single;
      expect(saved.name, 'Travel fund');
      expect(saved.targetAmount, 30000);
      expect(saved.targetDate, isNotNull);
      expect(GoalPlan.forGoal(saved, DateTime.now()).daily, greaterThan(0));
    });
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
    await tester.pump();
  });

  testWidgets('accounts and goal plan render in both themes at phone width', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final config =
          jsonDecode(
                await File('.dart_tool/package_config.json').readAsString(),
              )
              as Map;
      final root =
          (config['packages'] as List).firstWhere(
                (p) => p['name'] == 'flutter',
              )['rootUri']
              as String;
      final fonts = Uri.parse(
        root.endsWith('/') ? root : '$root/',
      ).resolve('../../bin/cache/artifacts/material_fonts/');
      for (final pair in [
        ('Roboto', 'roboto-regular.ttf'),
        ('MaterialIcons', 'materialicons-regular.otf'),
      ]) {
        final data = await File.fromUri(fonts.resolve(pair.$2)).readAsBytes();
        final loader = FontLoader(pair.$1)
          ..addFont(Future.value(ByteData.sublistView(data)));
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    final id = (await tester.runAsync(
      () => GoalRepo(
        db,
      ).insert(goal(date: DateTime.now().add(const Duration(days: 150)))),
    ))!;
    await tester.runAsync(() => container.read(firstRunProvider.future));
    await tester.runAsync(() => container.read(accountsProvider.future));
    await tester.runAsync(() => container.read(goalsProvider.future));
    for (final light in [true, false]) {
      for (final page in ['accounts', 'goal']) {
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: (light ? AppTheme.light : AppTheme.dark).copyWith(
                textTheme: (light ? AppTheme.light : AppTheme.dark).textTheme
                    .apply(fontFamily: 'Roboto'),
                filledButtonTheme: FilledButtonThemeData(
                  style: (light ? AppTheme.light : AppTheme.dark)
                      .filledButtonTheme
                      .style!
                      .copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                ),
                appBarTheme: (light ? AppTheme.light : AppTheme.dark)
                    .appBarTheme
                    .copyWith(
                      titleTextStyle: (light ? AppTheme.light : AppTheme.dark)
                          .appBarTheme
                          .titleTextStyle!
                          .copyWith(fontFamily: 'Roboto'),
                    ),
              ),
              themeAnimationDuration: Duration.zero,
              home: RepaintBoundary(
                key: key,
                child: page == 'accounts'
                    ? const AccountsScreen()
                    : GoalDetailScreen(goalId: id),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/qa').create(recursive: true);
          await File(
            'build/qa/$page-${light ? "light" : "dark"}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });

  testWidgets('transfer form requires confirmation and updates both accounts', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    final accountList = (await tester.runAsync(() => accounts.all()))!;
    await tester.runAsync(() => container.read(firstRunProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MoneyMovementDialog(accounts: accountList),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1000');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm transfer'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await tx.all(), isEmpty);
    });
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect((await tx.all()).single.type, TxType.transfer);
      expect(await accounts.totalBalance(), 5100);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
  testWidgets(
    'appearance switches from system to dark and light and persists',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          homeSummaryProvider.overrideWith(
            (ref) async => const HomeSummary(
              totalSavings: 5100,
              lastMonthSavings: 0,
              monthlyIncome: 0,
              monthlyExpenses: 0,
              monthlySaved: 0,
              monthlyGoal: 0,
              savingsRate: 0,
              activeGoals: [],
              insights: [],
              savingStreak: 0,
              loggingStreak: 0,
              netWorthChangePercent: 0,
            ),
          ),
        ],
      );
      await tester.runAsync(() => container.read(firstRunProvider.future));
      await tester.runAsync(() => container.read(settingsProvider.future));
      await tester.runAsync(
        () => container.read(customCategoriesProvider.future),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MoneyFlowApp(),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Settings').last);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(seconds: 1));
      for (final option in ['Dark mode', 'Light mode', 'System default']) {
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text(option).last);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump(const Duration(seconds: 1));
        final expected = option == 'Dark mode'
            ? 'dark'
            : option == 'Light mode'
            ? 'light'
            : 'system';
        await tester.runAsync(() async {
          expect((await SettingsRepo(db).load()).themeMode, expected);
        });
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode?.name,
          expected,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  test(
    'goal recommendations are rounded up and react to changed savings and deadline',
    () {
      final end = DateTime(2026, 9, 27);
      final plan = GoalPlan.forGoal(goal(date: end), now);
      expect(plan.days, 10);
      expect(plan.daily, 2000);
      expect(plan.weekly, 14000);
      expect(plan.monthly, 20000);
      expect(GoalPlan.forGoal(goal(saved: 20000, date: end), now).daily, 1000);
      expect(GoalPlan.forGoal(goal(saved: 0, date: end), now).daily, 3000);
      expect(
        GoalPlan.forGoal(goal(date: DateTime(2026, 10, 7)), now).daily,
        1000,
      );
      expect(
        GoalPlan.forGoal(
          goal(target: 1, saved: 0, date: DateTime(2026, 9, 20)),
          now,
        ).daily,
        .34,
      );
    },
  );
  test('goal date and completion edge cases', () {
    expect(GoalPlan.forGoal(goal(), now).message, contains('target date'));
    expect(
      GoalPlan.forGoal(goal(date: DateTime(2026, 9, 17)), now).message,
      contains('passed'),
    );
    expect(GoalPlan.forGoal(goal(date: now), now).daily, 20000);
    expect(GoalPlan.forGoal(goal(saved: 30000, date: now), now).daily, 0);
    expect(GoalPlan.forGoal(goal(target: 5000, date: now), now).remaining, 0);
  });
  test(
    'deposit withdraw transfer preserve total and keep transfer out of income/expenses',
    () async {
      await tx.moveMoney(movement(500.25, TxType.income));
      await tx.moveMoney(movement(100.25, TxType.expense));
      await tx.moveMoney(movement(1000, TxType.transfer, to: 'Cash'));
      final list = await accounts.all();
      expect(list.firstWhere((a) => a.name == 'Bank').balance, 4400);
      expect(list.firstWhere((a) => a.name == 'Cash').balance, 1100);
      expect(await accounts.totalBalance(), 5500);
      final activity = ActivitySummary(await tx.all(), []);
      expect(activity.income, 500.25);
      expect(activity.expenses, 100.25);
      expect(activity.net, 400);
      expect(
        (await tx.all())
            .where((t) => t.type == TxType.transfer)
            .single
            .destinationAccount,
        'Cash',
      );
    },
  );
  test('invalid movements rollback both accounts', () async {
    for (final amount in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1000000000.0,
      0.001,
    ]) {
      await expectLater(
        tx.moveMoney(movement(amount, TxType.transfer, to: 'Cash')),
        throwsA(isA<ArgumentError>()),
      );
    }
    await expectLater(
      tx.moveMoney(movement(5001, TxType.transfer, to: 'Cash')),
      throwsStateError,
    );
    await expectLater(
      tx.moveMoney(movement(5001, TxType.expense)),
      throwsStateError,
    );
    await expectLater(
      tx.moveMoney(movement(1, TxType.transfer, to: 'Bank')),
      throwsArgumentError,
    );
    await expectLater(
      tx.moveMoney(movement(1, TxType.transfer, to: 'Missing')),
      throwsStateError,
    );
    expect(await accounts.totalBalance(), 5100);
    expect(await tx.all(), isEmpty);
  });
  test('concurrent transfers cannot overspend', () async {
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        tx
            .moveMoney(movement(4000, TxType.transfer, to: 'Cash'))
            .then((_) => true)
            .catchError((_) => false),
    ]);
    expect(results.where((s) => s).length, 1);
    expect(await accounts.totalBalance(), 5100);
    expect(
      (await accounts.all()).firstWhere((a) => a.name == 'Bank').balance,
      1000,
    );
  });
  test(
    'transfer rename deletion and reversal keep account links and funds correct',
    () async {
      final id = await tx.moveMoney(
        movement(1000, TxType.transfer, to: 'Cash'),
      );
      final cash = (await accounts.all()).firstWhere((a) => a.name == 'Cash');
      await accounts.update(
        AccountRecord(
          id: cash.id,
          name: 'Wallet',
          type: cash.type,
          balance: cash.balance,
          color: cash.color,
        ),
      );
      expect((await tx.byId(id))!.destinationAccount, 'Wallet');
      await expectLater(accounts.delete(cash.id!), throwsStateError);
      await tx.delete(id);
      expect(
        (await accounts.all()).firstWhere((a) => a.name == 'Wallet').balance,
        100,
      );
      expect(await accounts.totalBalance(), 5100);
    },
  );
  test(
    'reversal fails safely when transferred money has already been spent',
    () async {
      final id = await tx.moveMoney(
        movement(1000, TxType.transfer, to: 'Cash'),
      );
      await tx.moveMoney(movement(1100, TxType.expense, from: 'Cash'));
      await expectLater(tx.delete(id), throwsStateError);
      expect(await tx.byId(id), isNotNull);
      expect(await accounts.totalBalance(), 4000);
    },
  );
  test(
    'goal withdrawals recalculate plan and stale edits do not lose contributions',
    () async {
      final repo = GoalRepo(db);
      final id = await repo.insert(
        goal(target: 1000, saved: 0, date: DateTime(2026, 9, 27)),
      );
      final stale = (await repo.all()).single;
      await repo.addContribution(
        GoalContribution(goalId: id, amount: 500, contributedAt: now),
      );
      await repo.update(stale.copyWith(name: 'Edited'));
      expect((await repo.all()).single.currentAmount, 500);
      expect(GoalPlan.forGoal((await repo.all()).single, now).daily, 50);
      await repo.withdraw(id, 200);
      expect(GoalPlan.forGoal((await repo.all()).single, now).daily, 70);
      await expectLater(repo.withdraw(id, 301), throwsStateError);
      expect(
        (await repo.allContributions()).fold<double>(0, (n, c) => n + c.amount),
        300,
      );
      expect(await accounts.totalBalance(), 5100);
    },
  );
  test(
    'version 2 migration adds defaults without replacing saved records',
    () async {
      await db.close();
      final raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await raw.execute(
        'CREATE TABLE settings (id INTEGER PRIMARY KEY, display_name TEXT, cutoff_hour INTEGER, currency TEXT)',
      );
      await raw.insert('settings', {
        'id': 1,
        'display_name': 'Maria',
        'cutoff_hour': 4,
        'currency': 'USD',
      });
      await raw.execute(
        'CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount REAL)',
      );
      await raw.insert('transactions', {'id': 5, 'amount': 125.25});
      final old = AppDatabase.forTesting(raw);
      await old.upgradeForTesting(2);
      expect((await raw.query('settings')).single['theme_mode'], 'system');
      expect((await raw.query('settings')).single['display_name'], 'Maria');
      expect((await raw.query('transactions')).single['amount'], 125.25);
      await old.close();
    },
  );
  test('theme and data survive a real database close and reopen', () async {
    final folder = await Directory.systemTemp.createTemp(
      'moneyflow-persistence-',
    );
    final path = '${folder.path}/test.db';
    final first = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(path),
    );
    await first.createSchemaForTesting();
    await SettingsRepo(first).save(
      const SettingsRecord(
        displayName: 'Maria',
        cutoffHour: 3,
        currency: 'USD',
        themeMode: 'light',
      ),
    );
    await AccountRepo(first).insert(
      const AccountRecord(
        name: 'Saved',
        type: 'cash',
        balance: 12.34,
        color: '#22C55E',
      ),
    );
    await first.close();
    final second = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(path),
    );
    await FirstRunInitializer(second).ensureInitialized();
    expect((await SettingsRepo(second).load()).themeMode, 'light');
    expect(await AccountRepo(second).totalBalance(), 12.34);
    await second.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await folder.delete();
  });
  test('backup roundtrip preserves destination and theme', () async {
    await tx.moveMoney(movement(125.25, TxType.transfer, to: 'Cash'));
    await SettingsRepo(db).save(
      const SettingsRecord(
        displayName: 'Maria',
        cutoffHour: 3,
        currency: 'PHP',
        themeMode: 'dark',
      ),
    );
    final backup = BackupService(db);
    await backup.restoreFromJsonString(await backup.exportJsonString());
    expect((await tx.all()).single.destinationAccount, 'Cash');
    expect((await SettingsRepo(db).load()).themeMode, 'dark');
    expect(await accounts.totalBalance(), 5100);
  });
}
