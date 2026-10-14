import 'core/widgets/startup_state.dart';
import 'features/goals/goal_photo_service.dart';
import 'core/constants/categories.dart';
import 'core/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_PH', null);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MoneyFlowApp()));
}

class MoneyFlowApp extends ConsumerStatefulWidget {
  const MoneyFlowApp({super.key});

  @override
  ConsumerState<MoneyFlowApp> createState() => _MoneyFlowAppState();
}

class _MoneyFlowAppState extends ConsumerState<MoneyFlowApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    // Eagerly initialize the database and run the first-run initializer
    // (which only ensures a default settings row exists — no demo data).
    ref.watch(recoveredGoalPhotoProvider);
    final dbAsync = ref.watch(databaseProvider);
    final firstRunAsync = ref.watch(firstRunProvider);
    final preference = firstRunAsync.hasValue
        ? ref.watch(settingsProvider).valueOrNull?.themeMode
        : 'system';

    return MaterialApp.router(
      title: 'MoneyFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (preference) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: _router,
      builder: (context, child) {
        return dbAsync.when(
          data: (_) => firstRunAsync.when(
            data: (_) => CurrencyScope(
              currency:
                  ref.watch(settingsProvider).valueOrNull?.currency ?? 'PHP',
              child: ref
                  .watch(customCategoriesProvider)
                  .when(
                    data: (categories) => CategoryScope(
                      categories: categories,
                      child: child ?? const SizedBox.shrink(),
                    ),
                    loading: () => const StartupLoading(),
                    error: (_, __) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () =>
                              ref.invalidate(customCategoriesProvider),
                          child: const Text('Could not load categories. Retry'),
                        ),
                      ),
                    ),
                  ),
            ),
            loading: () => const StartupLoading(),
            error: (_, __) => StartupFailure(
              onRetry: () {
                ref.invalidate(databaseProvider);
                ref.invalidate(firstRunProvider);
              },
            ),
          ),
          loading: () => const StartupLoading(),
          error: (_, __) => StartupFailure(
            onRetry: () {
              ref.invalidate(databaseProvider);
              ref.invalidate(firstRunProvider);
            },
          ),
        );
      },
    );
  }
}
