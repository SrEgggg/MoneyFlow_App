import 'support/goal_photo_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/core/utils/goal_history.dart';
import 'package:savings_app/core/utils/goal_photo_data.dart';
import 'package:savings_app/data/database/database.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/models/enums.dart';
import 'package:savings_app/data/repositories/repositories.dart';
import 'package:savings_app/data/seed/seed_data.dart';
import 'package:savings_app/data/services/backup_service.dart';
import 'package:savings_app/features/goals/create_goal_screen.dart';
import 'package:savings_app/features/goals/goal_photo_service.dart';
import 'package:savings_app/features/goals/widgets/goal_activity.dart';
import 'package:savings_app/features/goals/widgets/goal_image.dart';
import 'package:savings_app/providers.dart';

class FakePhotos extends GoalPhotoService {
  String? selected;
  FakePhotos(this.selected);
  @override
  Future<String?> pick() async => selected;
  @override
  Future<String?> recover() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final date = DateTime(2026, 9, 27);
  GoalRecord goal({String? photo, double saved = 300}) => GoalRecord(
    name: 'Laptop',
    kind: GoalKind.emergency,
    icon: 'emergency',
    targetAmount: 1000,
    currentAmount: saved,
    startedAt: date,
    targetDate: date.add(const Duration(days: 30)),
    status: GoalStatus.active,
    photo: photo,
  );
  setUp(() async {
    sqfliteFfiInit();
    db = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    await db.createSchemaForTesting();
    await FirstRunInitializer(db).ensureInitialized();
  });
  tearDown(() async => db.close());
  test(
    'photo normalization bounds size, preserves aspect ratio and rejects invalid data',
    () async {
      final photo = await GoalPhotoService.prepare(await sampleImage());
      final bytes = GoalPhotoData.decode(photo)!;
      expect(bytes.length, lessThanOrEqualTo(GoalPhotoData.maxBytes));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 768);
      expect(frame.image.height, 512);
      frame.image.dispose();
      codec.dispose();
      await expectLater(
        GoalPhotoService.prepare(Uint8List.fromList([0, 1, 2])),
        throwsA(anything),
      );
      expect(() => GoalPhotoData.decode('invalid'), throwsFormatException);
    },
  );
  test(
    'version five upgrade preserves existing goals and adds nullable photos',
    () async {
      final raw = await db.database;
      await raw.execute('ALTER TABLE goals DROP COLUMN photo');
      await raw.insert('goals', goal().toRow()..remove('photo'));
      await db.upgradeForTesting(5);
      final saved = (await GoalRepo(db).all()).single;
      expect(saved.currentAmount, 300);
      expect(saved.name, 'Laptop');
      expect(saved.photo, isNull);
    },
  );
  test(
    'photo edit removal backup and malformed restore preserve savings',
    () async {
      final photo = await GoalPhotoService.prepare(await sampleImage());
      final repo = GoalRepo(db);
      await repo.insert(goal(photo: photo));
      final exported = await BackupService(db).exportJsonString();
      final record = (await repo.all()).single;
      await repo.update(record.copyWith(clearPhoto: true));
      expect((await repo.all()).single.photo, isNull);
      await BackupService(db).restoreFromJsonString(exported);
      expect((await repo.all()).single.photo, photo);
      expect((await repo.all()).single.currentAmount, 300);
      final bad = jsonDecode(exported) as Map;
      bad['tables']['goals'][0]['photo'] = 'invalid';
      await expectLater(
        BackupService(db).restoreFromJsonString(jsonEncode(bad)),
        throwsFormatException,
      );
      expect((await repo.all()).single.photo, photo);
      final legacy = jsonDecode(exported) as Map;
      legacy['format'] = 5;
      legacy['tables']['goals'][0].remove('photo');
      await BackupService(db).restoreFromJsonString(jsonEncode(legacy));
      expect((await repo.all()).single.photo, isNull);
      expect((await repo.all()).single.currentAmount, 300);
    },
  );
  test('goal photo survives closing and reopening the database', () async {
    final photo = await GoalPhotoService.prepare(await sampleImage());
    final dir = await Directory.systemTemp.createTemp('goal-photo-restart-');
    final path = '${dir.path}/goals.db';
    var store = AppDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(path),
    );
    try {
      await store.createSchemaForTesting();
      await GoalRepo(store).insert(goal(photo: photo));
      await store.close();
      store = AppDatabase.forTesting(
        await databaseFactoryFfi.openDatabase(path),
      );
      final restored = (await GoalRepo(store).all()).single;
      expect(restored.photo, photo);
      expect(restored.currentAmount, 300);
    } finally {
      await store.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await dir.delete();
    }
  });

  test(
    'backup summary reads complete backups beyond the old 64 KB limit',
    () async {
      final folder = await Directory.systemTemp.createTemp('goal-backup-');
      final file = File('${folder.path}/backup.json');
      try {
        await file.writeAsString(
          '${await BackupService(db).exportJsonString()}${' ' * 70000}',
        );
        expect(
          (await BackupFileSummary.peek(file)).format,
          kBackupFormatVersion,
        );
      } finally {
        await file.delete();
        await folder.delete();
      }
    },
  );
  test('goal history separates additions removals and starting allocation', () {
    final records = [
      GoalContribution(goalId: 1, amount: 200, contributedAt: date),
      GoalContribution(
        goalId: 1,
        amount: -50,
        contributedAt: date.add(const Duration(days: 1)),
      ),
      GoalContribution(
        goalId: 1,
        amount: 100,
        contributedAt: date.add(const Duration(days: 2)),
      ),
    ];
    final history = GoalHistory(goal(saved: 550), records.reversed.toList());
    expect(history.openingAmount, 300);
    expect(history.added, 300);
    expect(history.removed, 50);
    expect(history.dailyBalances.values.toList(), [500, 450, 550]);
  });
  testWidgets(
    'photo selection cancellation and removal save without changing allocation',
    (tester) async {
      final photo = (await tester.runAsync(
        () async => GoalPhotoService.prepare(await sampleImage()),
      ))!;
      await tester.runAsync(() => GoalRepo(db).insert(goal()));
      final original = (await tester.runAsync(
        () => GoalRepo(db).all(),
      ))!.single;
      final photos = FakePhotos(photo);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((_) async => db),
          goalPhotoServiceProvider.overrideWithValue(photos),
        ],
      );
      await tester.runAsync(() => container.read(databaseProvider.future));
      await tester.runAsync(() => container.read(firstRunProvider.future));
      await tester.runAsync(() => container.read(goalsProvider.future));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Saved')),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, __) => CreateGoalScreen(goal: original),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      router.push('/edit');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(tester.widget<GoalImage>(find.byType(GoalImage)).photo, photo);
      photos.selected = null;
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      expect(tester.widget<GoalImage>(find.byType(GoalImage)).photo, photo);
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(tester.widget<GoalImage>(find.byType(GoalImage)).photo, isNull);
      photos.selected = photo;
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      final save = find.text('Save Changes');
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(() => GoalRepo(db).all()))!.single;
      expect(saved.photo, photo);
      expect(saved.currentAmount, 300);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
    },
  );
  testWidgets(
    'goal journey uses real history and remains usable at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = GoalRepo(db);
      final id = (await tester.runAsync(() => repo.insert(goal())))!;
      await tester.runAsync(() async {
        await repo.addContribution(
          GoalContribution(
            goalId: id,
            amount: 100,
            contributedAt: date.subtract(const Duration(days: 3)),
          ),
        );
        await repo.addContribution(
          GoalContribution(
            goalId: id,
            amount: 100,
            contributedAt: date.subtract(const Duration(days: 2)),
          ),
        );
        await repo.withdraw(id, 50);
      });
      final saved = (await tester.runAsync(() => repo.all()))!.single;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((_) async => db)],
      );
      await tester.runAsync(() => container.read(databaseProvider.future));
      await tester.runAsync(() => container.read(firstRunProvider.future));
      await tester.runAsync(() => container.read(goalsProvider.future));
      await tester.runAsync(
        () => container.read(goalActivityProvider(id).future),
      );
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(child: GoalActivity(goal: saved)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scale == 1) {
          expect(
            tester
                .widget<LineChart>(find.byType(LineChart))
                .data
                .lineBarsData
                .single
                .spots
                .last
                .y,
            450,
          );
        } else {
          expect(find.byType(LineChart), findsNothing);
        }
        expect(find.text('Removed from goal'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      container.dispose();
    },
  );
}
