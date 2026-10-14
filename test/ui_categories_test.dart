import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/core/constants/categories.dart';
import 'package:savings_app/core/utils/activity_summary.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/repositories/category_repository.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/data/services/backup_service.dart';
import 'package:savings_app/features/performance/performance_screen.dart';
import 'package:savings_app/features/transactions/widgets/category_picker.dart';
import 'package:savings_app/features/transactions/widgets/quick_add_form.dart';
import 'package:savings_app/features/transactions/widgets/transaction_list.dart';
import 'package:savings_app/features/transactions/transaction_detail_screen.dart';
import 'package:savings_app/providers.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categories;
  final now = DateTime(2026, 9, 21, 12);
  TxRecord entry(
    String category,
    double amount,
    DateTime date, {
    TxType type = TxType.expense,
  }) => TxRecord(
    id: 1,
    amount: amount,
    type: type,
    category: category,
    account: 'Cash',
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
    categories = CategoryRepository(db);
    await AccountRepo(db).insert(
      const AccountRecord(
        name: 'Cash',
        type: 'cash',
        balance: 2000,
        color: '#22C55E',
      ),
    );
  });
  tearDown(() async => (await db.database).close());

  test(
    'category names normalize; blank and duplicate names fail without inserting',
    () async {
      final category = await categories.create(
        '  Pet   care  ',
        'expense',
        iconKey: 'pets',
        color: customCategoryColors[2],
      );
      expect(category.name, 'Pet care');
      expect(category.icon, Icons.pets);
      for (final name in [
        '',
        '  ',
        'pet care',
        ' PET   CARE ',
        'Food & Dining',
        'Salary',
        'Transfer',
        'x' * 33,
      ]) {
        await expectLater(
          categories.create(name, 'expense'),
          throwsFormatException,
        );
      }
      expect((await categories.all()).length, 1);
      await expectLater(
        categories.create('New', 'transfer'),
        throwsFormatException,
      );
      await expectLater(
        categories.create('New', 'expense', iconKey: 'unknown'),
        throwsFormatException,
      );
    },
  );

  test(
    'concurrent duplicate category creation has exactly one winner',
    () async {
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          categories
              .create('Side jobs', 'income')
              .then((_) => true)
              .catchError((_) => false),
      ]);
      expect(results.where((r) => r).length, 1);
      expect((await categories.all()).length, 1);
    },
  );

  test(
    'custom metadata and transaction IDs survive backup restore; older backups load',
    () async {
      final category = await categories.create(
        'Pet care',
        'expense',
        iconKey: 'pets',
      );
      await TransactionRepo(db).insert(entry(category.id, 125, now));
      final backup = await BackupService(db).exportJsonString();
      await db.wipe();
      await BackupService(db).restoreFromJsonString(backup);
      final restored = (await categories.all()).single;
      expect(restored.id, category.id);
      expect(restored.icon, category.icon);
      expect(restored.color, category.color);
      expect((await TransactionRepo(db).all()).single.category, category.id);
      expect((await AccountRepo(db).all()).single.balance, 1875);
      final legacy = jsonDecode(backup) as Map<String, dynamic>;
      legacy['format'] = 3;
      (legacy['tables'] as Map).remove('custom_categories');
      (legacy['tables'] as Map)['transactions'] = <Object>[];
      await BackupService(db).restoreFromJsonString(jsonEncode(legacy));
      expect(await categories.all(), isEmpty);
    },
  );

  test(
    'v3 migration adds categories without changing saved account or transaction',
    () async {
      await TransactionRepo(db).insert(entry('food_dining', 50, now));
      await (await db.database).execute('DROP TABLE custom_categories');
      await db.upgradeForTesting(3);
      expect(await categories.all(), isEmpty);
      expect((await TransactionRepo(db).all()).single.amount, 50);
      expect((await AccountRepo(db).all()).single.balance, 1950);
    },
  );

  test(
    'custom category persists after the database is closed and reopened',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'moneyflow-categories-',
      );
      final path = '${directory.path}/categories.db';
      final local = AppDatabase.forTesting(
        await databaseFactoryFfi.openDatabase(path),
      );
      await local.createSchemaForTesting();
      final saved = await CategoryRepository(
        local,
      ).create('Side projects', 'income', iconKey: 'work');
      await (await local.database).close();
      final reopened = AppDatabase.forTesting(
        await databaseFactoryFfi.openDatabase(path),
      );
      try {
        final loaded = (await CategoryRepository(reopened).all()).single;
        expect(loaded.id, saved.id);
        expect(loaded.name, 'Side projects');
        expect(loaded.kind, 'income');
        expect(loaded.icon, Icons.work_outline);
      } finally {
        await (await reopened.database).close();
        await File(path).delete();
        await directory.delete();
      }
    },
  );

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  Widget host(ProviderContainer container, Widget child, {ThemeData? theme}) =>
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: theme ?? AppTheme.light,
            builder: (_, child) => CategoryScope(
              categories: ref.watch(customCategoriesProvider).valueOrNull ?? [],
              child: child!,
            ),
            home: child,
          ),
        ),
      );

  testWidgets('custom picker validates, saves, selects and reuses category', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((_) async => db)],
    );
    await tester.runAsync(
      () => container.read(customCategoriesProvider.future),
    );
    String? selected;
    await tester.pumpWidget(
      host(
        container,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CategoryPicker(
              kind: 'expense',
              selected: selected,
              onChanged: (id) => setState(() => selected = id),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Other / Custom category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save category'));
    await settleDb(tester);
    expect(
      find.text('Enter a category name of 1 to 32 characters.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Pet care');
    await tester.tap(find.byTooltip('pets'));
    await tester.tap(find.byTooltip('Purple'));
    await tester.tap(find.text('Save category'));
    await settleDb(tester);
    expect(find.text('Pet care'), findsOneWidget);
    final saved = (await tester.runAsync(() => categories.all()))!.single;
    expect(selected, saved.id);
    expect(saved.icon, Icons.pets);
    expect(saved.color, customCategoryColors[2]);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Pet care'),
    );
    expect(chip.selected, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    final reopened = ProviderContainer(
      overrides: [databaseProvider.overrideWith((_) async => db)],
    );
    await tester.runAsync(() => reopened.read(customCategoriesProvider.future));
    await tester.pumpWidget(
      host(
        reopened,
        Scaffold(
          body: CategoryPicker(
            kind: 'expense',
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Pet care'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    reopened.dispose();
  });

  testWidgets(
    'custom category works in add, history search and transaction editing',
    (tester) async {
      final category = (await tester.runAsync(
        () => categories.create('Pet care', 'expense'),
      ))!;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((_) async => db)],
      );
      await tester.runAsync(() async {
        await container.read(firstRunProvider.future);
        await container.read(settingsProvider.future);
        await container.read(customCategoriesProvider.future);
        await container.read(accountsProvider.future);
        await container.read(transactionsProvider.future);
      });
      final accounts = container.read(accountsProvider).requireValue;
      var saved = false;
      await tester.pumpWidget(
        host(
          container,
          Scaffold(
            body: QuickAddForm(accounts: accounts, onSaved: () => saved = true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '120');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Pet care')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pet care').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Pet care'));
      await tester.pumpAndSettle();
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
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await settleDb(tester);
      expect(
        saved,
        isTrue,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      final tx = (await tester.runAsync(
        () => TransactionRepo(db).all(),
      ))!.single;
      expect(tx.category, category.id);
      await tester.pumpWidget(
        host(
          container,
          Scaffold(
            body: TransactionList(txs: [tx], onTap: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'pet');
      await tester.pumpAndSettle();
      expect(find.text('Pet care'), findsWidgets);
      await tester.pumpWidget(
        host(container, TransactionDetailScreen(transactionId: tx.id!)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.byIcon(Icons.edit_outlined)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pet care'))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.text('Food & Dining'));
      await tester.tap(find.text('Food & Dining'));
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Save Changes'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      for (
        var attempt = 0;
        attempt < 80 && find.text('Transaction updated').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Transaction updated'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => TransactionRepo(db).all(),
        ))!.single.category,
        'food_dining',
      );
      expect(
        (await tester.runAsync(() => AccountRepo(db).all()))!.single.balance,
        1880,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'performance ranges, category drilldown and calendar remain usable on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final category = (await tester.runAsync(
        () => categories.create('Pet care', 'expense', iconKey: 'pets'),
      ))!;
      final activity = ActivitySummary([
        entry(category.id, 120, now),
        entry('food_dining', 200, now.subtract(const Duration(days: 10))),
        entry('salary', 1500, now, type: TxType.income),
      ], []);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((_) async => db),
          activityProvider.overrideWith((_) async => activity),
          activityClockProvider.overrideWith((_) => Stream.value(now)),
        ],
      );
      await tester.runAsync(
        () => container.read(customCategoriesProvider.future),
      );
      await tester.pumpWidget(host(container, const PerformanceScreen()));
      await settleDb(tester);
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.text('7D'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Expenses'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Expenses'), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('Expenses'), matching: find.byType(Row))
              .first,
          matching: find.text('₱120'),
        ),
        findsOneWidget,
      );
      expect(find.text('₱320'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Pet care'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Pet care')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pet care').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Pet care'));
      await tester.pumpAndSettle();
      expect(find.text('Pet care'), findsWidgets);
      Navigator.of(tester.element(find.text('Pet care').last)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await settleDb(tester);
      expect(find.byTooltip('Previous month'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('performance has useful empty state and renders light and dark', (
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
        await (FontLoader(
          pair.$1,
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var renderedActivity = ActivitySummary([], []);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) async => db),
        activityProvider.overrideWith((_) async => renderedActivity),
        activityClockProvider.overrideWith((_) => Stream.value(now)),
      ],
    );
    await tester.runAsync(
      () => container.read(customCategoriesProvider.future),
    );
    for (final dark in [false, true]) {
      final base = dark ? AppTheme.dark : AppTheme.light;
      final theme = base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
        chipTheme: base.chipTheme.copyWith(
          labelStyle: base.chipTheme.labelStyle!.copyWith(fontFamily: 'Roboto'),
        ),
        tabBarTheme: base.tabBarTheme.copyWith(
          labelStyle: const TextStyle(fontFamily: 'Roboto'),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto'),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
            fontFamily: 'Roboto',
          ),
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        host(
          container,
          RepaintBoundary(key: key, child: const PerformanceScreen()),
          theme: theme,
        ),
      );
      await settleDb(tester);
      expect(
        find.text(
          'No activity in this period. Record a transaction or choose a different range.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/qa').create(recursive: true);
        await File(
          'build/qa/performance-${dark ? 'dark' : 'light'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      renderedActivity = ActivitySummary([
        entry(
          'salary',
          1500,
          now.subtract(const Duration(days: 15)),
          type: TxType.income,
        ),
        entry('food_dining', 320, now),
      ], []);
      container.invalidate(activityProvider);
      await settleDb(tester);
      expect(find.text('Net cash flow'), findsOneWidget);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/qa/performance-data-${dark ? 'dark' : 'light'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      renderedActivity = ActivitySummary([], []);
      container.invalidate(activityProvider);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
