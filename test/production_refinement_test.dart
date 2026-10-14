import 'package:savings_app/features/home/widgets/today_check_in.dart';
import 'package:savings_app/features/goals/widgets/quick_goal_savings.dart';
import 'package:savings_app/features/performance/journal_tab.dart';
import 'package:savings_app/features/performance/reviews_tab.dart';
import 'support/goal_photo_fixture.dart';
import 'package:savings_app/features/goals/goal_photo_service.dart';
import 'package:savings_app/features/goals/create_goal_screen.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/main.dart';
import 'package:savings_app/core/constants/categories.dart';
import 'package:savings_app/core/utils/activity_summary.dart';
import 'package:savings_app/core/utils/analytics_window.dart';
import 'package:savings_app/core/utils/money.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/repositories/category_repository.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/data/services/backup_service.dart';
import 'package:savings_app/features/home/home_screen.dart';
import 'package:savings_app/features/accounts/accounts_screen.dart';
import 'package:savings_app/features/goals/goals_screen.dart';
import 'package:savings_app/features/goals/goal_detail_screen.dart';
import 'package:savings_app/features/performance/performance_screen.dart';
import 'package:savings_app/features/settings/settings_screen.dart';
import 'package:savings_app/features/transactions/transactions_screen.dart';
import 'package:savings_app/features/transactions/widgets/category_management_screen.dart';
import 'package:savings_app/features/transactions/widgets/quick_add_form.dart';
import 'package:savings_app/providers.dart';

void main() {
  late AppDatabase db;
  final today = DateTime.now();
  TxRecord tx({
    double amount = 100,
    TxType type = TxType.expense,
    String category = 'food_dining',
    DateTime? date,
  }) => TxRecord(
    amount: amount,
    type: type,
    category: category,
    account: 'Cash',
    occurredAt: date ?? today,
    createdAt: today,
    updatedAt: today,
  );
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    await AccountRepo(db).insert(
      const AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 10000,
        color: '#22C55E',
      ),
    );
  });
  tearDown(() async => (await db.database).close());

  test('one money policy preserves cents and puts minus before currency', () {
    for (final pair in [
      (0, '₱0'),
      (1250, '₱1,250'),
      (12500.5, '₱12,500.50'),
      (-.5, '-₱0.50'),
    ]) {
      expect(Money.format(pair.$1), pair.$2);
      expect(const MoneyFormatter('PHP').format(pair.$1), pair.$2);
    }
    expect(Money.formatSigned(12.5), '+₱12.50');
    expect(Money.formatDecimal(-12.5), '-₱12.50');
  });

  test(
    'period comparison uses adjacent days and caps previous month correctly',
    () {
      final week = AnalyticsWindow(DateTime(2026, 3, 3), 7);
      expect(week.start, DateTime(2026, 2, 25));
      expect(week.previousEnd, week.start);
      expect(week.previousStart, DateTime(2026, 2, 18));
      final month = AnalyticsWindow(DateTime(2026, 3, 31), 0);
      expect(month.previousStart, DateTime(2026, 2));
      expect(month.previousEnd, DateTime(2026, 3));
      final all = ActivitySummary([
        tx(date: DateTime(2026, 2, 24)),
        tx(date: DateTime(2026, 2, 25)),
        tx(date: DateTime(2026, 3, 4)),
      ], []);
      expect(week.current(all).expenses, 100);
      expect(week.previous(all).expenses, 100);
    },
  );

  test(
    'Undo restores exact balance and cannot erase an edited transaction',
    () async {
      final repo = TransactionRepo(db);
      final original = tx();
      final id = await repo.insert(original);
      await repo.undoAdded(original.copyWith(id: id));
      expect(await repo.all(), isEmpty);
      expect((await AccountRepo(db).all()).single.balance, 10000);
      await expectLater(
        repo.undoAdded(original.copyWith(id: id)),
        throwsStateError,
      );
      final next = await repo.insert(original);
      await repo.update(original.copyWith(id: next, amount: 200));
      await expectLater(
        repo.undoAdded(original.copyWith(id: next)),
        throwsStateError,
      );
      expect((await repo.all()).single.amount, 200);
      expect((await AccountRepo(db).all()).single.balance, 9800);
    },
  );

  test(
    'Undo income rejects funds already spent without changing history',
    () async {
      final repo = TransactionRepo(db);
      final income = tx(amount: 300, type: TxType.income, category: 'salary');
      final id = await repo.insert(income);
      await repo.insert(tx(amount: 10200));
      await expectLater(
        repo.undoAdded(income.copyWith(id: id)),
        throwsStateError,
      );
      expect((await repo.all()).length, 2);
      expect((await AccountRepo(db).all()).single.balance, 100);
    },
  );

  test(
    'category edit keeps links; removal preserves history and backup labels',
    () async {
      final repo = CategoryRepository(db);
      final category = await repo.create('Pet care', 'expense');
      await TransactionRepo(db).insert(tx(category: category.id));
      await repo.create(
        'Veterinary',
        'expense',
        existingId: category.id,
        iconKey: 'pets',
      );
      expect((await repo.all()).single.name, 'Veterinary');
      expect((await TransactionRepo(db).all()).single.category, category.id);
      await repo.remove(category.id);
      expect((await repo.all()).single.archived, isTrue);
      final replacement = await repo.create('Veterinary', 'expense');
      expect(replacement.id, isNot(category.id));
      final backup = await BackupService(db).exportJsonString();
      await BackupService(db).restoreFromJsonString(backup);
      final removed = (await repo.all()).firstWhere((c) => c.id == category.id);
      expect(removed.name, 'Veterinary');
      expect(removed.icon, Icons.pets);
      expect(removed.archived, isTrue);
      expect((await AccountRepo(db).all()).single.balance, 9900);
    },
  );

  test('schema v4 migration retains custom category data', () async {
    final database = await db.database;
    await database.execute('DROP TABLE custom_categories');
    await database.execute(
      'CREATE TABLE custom_categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, normalized_name TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, icon_key TEXT NOT NULL, color_value INTEGER NOT NULL)',
    );
    await database.insert('custom_categories', {
      'id': 'custom_old',
      'name': 'Old category',
      'normalized_name': 'old category',
      'kind': 'expense',
      'icon_key': 'home',
      'color_value': 0xFF3B82F6,
    });
    await db.upgradeForTesting(4);
    final old = (await CategoryRepository(db).all()).single;
    expect(old.name, 'Old category');
    expect(old.archived, isFalse);
  });

  Future<ProviderContainer> containerFor(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) async => db),
        activityClockProvider.overrideWith((_) => Stream.value(today)),
      ],
    );
    await tester.runAsync(() async {
      await container.read(firstRunProvider.future);
      await container.read(settingsProvider.future);
      await container.read(accountsProvider.future);
      await container.read(transactionsProvider.future);
      await container.read(goalsProvider.future);
      await container.read(customCategoriesProvider.future);
      await container.read(activityProvider.future);
    });
    return container;
  }

  Future<void> finishAsync(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
  }

  Widget host(
    ProviderContainer container,
    Widget child, {
    bool dark = true,
    double scale = 1,
  }) {
    final base = dark ? AppTheme.dark : AppTheme.light;
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: const TextStyle(fontFamily: 'Roboto'),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto'),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Roboto'),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: base.chipTheme.labelStyle!.copyWith(fontFamily: 'Roboto'),
      ),
    );
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => CategoryScope(
            categories: ref.watch(customCategoriesProvider).valueOrNull ?? [],
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: child,
        ),
      ),
    );
  }

  testWidgets('today check-in opens a bounded transaction form', (
    tester,
  ) async {
    final container = await containerFor(tester);
    await tester.pumpWidget(
      host(container, const Scaffold(body: TodayCheckIn())),
    );
    await finishAsync(tester);
    expect(find.text('Your day, at a glance'), findsOneWidget);
    await tester.tap(find.text('Your day, at a glance'));
    await tester.pumpAndSettle();
    expect(find.text('Today’s activity'), findsOneWidget);
    await tester.ensureVisible(find.text('Add Transaction'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Add Transaction'));
    });
    await finishAsync(tester);
    expect(find.byType(QuickAddForm), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, '120');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save Expense'));
    });
    await finishAsync(tester);
    expect(find.byType(QuickAddForm), findsNothing);
    expect(find.text('Today’s activity'), findsOneWidget);
    expect(
      container.read(activityProvider).requireValue.on(today).expenses,
      120,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets(
    'home savings suggestions need confirmation and preserve account money',
    (tester) async {
      await tester.runAsync(
        () => GoalRepo(db).insert(
          GoalRecord(
            name: 'Weekend fund',
            kind: GoalKind.emergency,
            icon: 'emergency',
            targetAmount: 100,
            currentAmount: 0,
            startedAt: today,
            targetDate: today.add(const Duration(days: 30)),
            status: GoalStatus.active,
          ),
        ),
      );
      final container = await containerFor(tester);
      final goal = container.read(goalsProvider).requireValue.single;
      await tester.pumpWidget(
        host(container, Scaffold(body: QuickGoalSavings(goal: goal))),
      );
      await tester.tap(find.text('Add savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('A day ·'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isNotEmpty,
      );
      expect(
        container.read(goalsProvider).requireValue.single.currentAmount,
        0,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container.read(goalsProvider).requireValue.single.currentAmount,
        0,
      );
      await tester.tap(find.text('Add savings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Add savings'));
      });
      await finishAsync(tester);
      expect(
        container.read(goalsProvider).requireValue.single.currentAmount,
        100,
      );
      expect(find.text('Goal reached: Weekend fund'), findsOneWidget);
      expect(
        (await tester.runAsync(() => AccountRepo(db).all()))!.single.balance,
        10000,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'transaction confirmation Undo restores history and account balance',
    (tester) async {
      final container = await containerFor(tester);
      final accounts = container.read(accountsProvider).requireValue;
      await tester.pumpWidget(
        host(
          container,
          Scaffold(
            body: QuickAddForm(accounts: accounts, onSaved: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '125.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save Expense'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save Expense'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await finishAsync(tester);
      expect(find.textContaining('Expense added'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Undo'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await finishAsync(tester);
      expect(
        (await tester.runAsync(() => TransactionRepo(db).all()))!,
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => AccountRepo(db).all()))!.single.balance,
        10000,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'category deletion requires confirmation and keeps historical label',
    (tester) async {
      final category = (await tester.runAsync(
        () => CategoryRepository(db).create('Pet care', 'expense'),
      ))!;
      final container = await containerFor(tester);
      await tester.pumpWidget(
        host(container, const CategoryManagementScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete Pet care'));
      await tester.pumpAndSettle();
      expect(find.text('Delete category?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => CategoryRepository(db).all(),
        ))!.single.archived,
        isFalse,
      );
      await tester.tap(find.byTooltip('Delete Pet care'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Delete'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await finishAsync(tester);
      expect(
        (await tester.runAsync(() => CategoryRepository(db).all()))!.single.id,
        category.id,
      );
      expect(
        (await tester.runAsync(
          () => CategoryRepository(db).all(),
        ))!.single.archived,
        isTrue,
      );
      expect(find.text('Pet care'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('bottom navigation works on a small phone with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousErrorHandler!(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await containerFor(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MoneyFlowApp(),
      ),
    );
    await finishAsync(tester);
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await finishAsync(tester);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Navigation destination $index',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  test('supporting text and primary buttons meet normal-text contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final surface in [
        theme.colorScheme.surface,
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.surfaceContainerHighest,
      ]) {
        expect(
          contrast(theme.colorScheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(AppColors.onPrimary, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'save stays above keyboard and optional notes remain accessible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final container = await containerFor(tester);
      await tester.pumpWidget(
        host(
          container,
          Scaffold(
            body: QuickAddForm(
              accounts: container.read(accountsProvider).requireValue,
              onSaved: () {},
            ),
          ),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(
              find.ancestor(
                of: find.text('Save Expense'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              ),
            )
            .bottom,
        lessThanOrEqualTo(380),
      );
      final notes = find.text('Add a note (optional)');
      await tester.scrollUntilVisible(
        notes,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(notes);
      await tester.pumpAndSettle();
      await tester.tap(notes);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.maxLines == 2),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'goal saving and removal preserve accounts and management is secondary',
    (tester) async {
      final id = (await tester.runAsync(
        () => GoalRepo(db).insert(
          GoalRecord(
            name: 'Laptop',
            kind: GoalKind.emergency,
            icon: 'emergency',
            targetAmount: 1000,
            currentAmount: 0,
            startedAt: today,
            targetDate: today.add(const Duration(days: 30)),
            status: GoalStatus.active,
          ),
        ),
      ))!;
      final container = await containerFor(tester);
      await tester.pumpWidget(host(container, GoalDetailScreen(goalId: id)));
      await finishAsync(tester);
      expect(find.text('Delete Goal'), findsNothing);
      await tester.ensureVisible(find.text('Add savings'));
      await tester.tap(find.text('Add savings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Add savings').last);
      await finishAsync(tester);
      expect(
        container.read(goalsProvider).requireValue.single.currentAmount,
        100,
      );
      final remove = find.text('Remove from goal');
      await tester.scrollUntilVisible(
        remove,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Account balances stay unchanged'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('Remove savings'));
      await finishAsync(tester);
      expect(
        container.read(goalsProvider).requireValue.single.currentAmount,
        0,
      );
      expect(
        (await tester.runAsync(() => AccountRepo(db).all()))!.single.balance,
        10000,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('recorded cash flow chart remains readable with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await TransactionRepo(
          db,
        ).insert(tx(amount: 100, date: today.subtract(Duration(days: i))));
      }
    });
    final container = await containerFor(tester);
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        host(container, const PerformanceScreen(), scale: scale),
      );
      await finishAsync(tester);
      await tester.tap(find.text('7D'));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart);
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      expect(
        tester.widget<LineChart>(chart).data.lineBarsData.single.spots.last.y,
        -500,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets(
    'primary screens fit small normal large phones in both themes and large text',
    (tester) async {
      await tester.runAsync(() async {
        await TransactionRepo(db).insert(
          tx(
            amount: 12000,
            type: TxType.income,
            category: 'salary',
            date: today.subtract(const Duration(days: 3)),
          ),
        );
        await TransactionRepo(db).insert(tx(amount: 350.5));
        await GoalRepo(db).insert(
          GoalRecord(
            name: 'Laptop and work equipment',
            photo: await GoalPhotoService.prepare(await sampleImage()),
            kind: GoalKind.emergency,
            icon: 'emergency',
            targetAmount: 30000,
            currentAmount: 18500,
            startedAt: today,
            targetDate: today.add(const Duration(days: 100)),
            status: GoalStatus.active,
          ),
        );
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
          final bytes = await File.fromUri(
            fonts.resolve(pair.$2),
          ).readAsBytes();
          await (FontLoader(
            pair.$1,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      });
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        originalErrorHandler!(details);
      };
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await containerFor(tester);
      final goal = container.read(goalsProvider).requireValue.single;
      for (final layout in [
        (320.0, 640.0, 1.0),
        (390.0, 844.0, 1.0),
        (430.0, 932.0, 1.0),
        (320.0, 640.0, 1.6),
        (390.0, 844.0, 2.0),
      ]) {
        tester.view.physicalSize = Size(layout.$1, layout.$2);
        for (final dark in [true, false]) {
          for (final page in <String, Widget>{
            'home': const HomeScreen(),
            'transactions': const TransactionsScreen(),
            'goals': const GoalsScreen(),
            'goal': GoalDetailScreen(goalId: goal.id!),
            'goal-edit': CreateGoalScreen(goal: goal),
            'performance': const PerformanceScreen(),
            'accounts': const AccountsScreen(),
            'settings': const SettingsScreen(),
            'journal': Scaffold(
              appBar: AppBar(title: const Text('Journal')),
              body: const JournalTab(),
            ),
            'reviews': Scaffold(
              appBar: AppBar(title: const Text('Monthly reviews')),
              body: const ReviewsTab(),
            ),
          }.entries) {
            final key = GlobalKey();
            await tester.pumpWidget(
              host(
                container,
                RepaintBoundary(key: key, child: page.value),
                dark: dark,
                scale: layout.$3,
              ),
            );
            await finishAsync(tester);
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.key} ${layout.$1} / ${layout.$3} dark=$dark',
            );
            if (layout.$1 == 390 &&
                layout.$3 == 1 &&
                [
                  'home',
                  'performance',
                  'goals',
                  'goal',
                  'goal-edit',
                  'accounts',
                  'transactions',
                  'settings',
                ].contains(page.key)) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory('build/qa').create(recursive: true);
                await File(
                  'build/qa/refined-${page.key}-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            final scrolls = find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            );
            if (scrolls.evaluate().isNotEmpty) {
              for (var i = 0; i < 3; i++) {
                await tester.drag(scrolls.first, const Offset(0, -350));
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${page.key} scrolled ${layout.$1}/${layout.$3}',
                );
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
      container.dispose();
    },
    tags: ['layout'],
  );
}
