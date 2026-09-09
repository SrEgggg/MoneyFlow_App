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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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
    final dbAsync = ref.watch(databaseProvider);
    final firstRunAsync = ref.watch(firstRunProvider);

    return MaterialApp.router(
      title: 'MoneyFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      builder: (context, child) {
        return dbAsync.when(
          data: (_) => firstRunAsync.when(
            data: (_) => child ?? const SizedBox.shrink(),
            loading: () => const _Splash(),
            error: (e, st) => _ErrorView(message: e.toString()),
          ),
          loading: () => const _Splash(),
          error: (e, st) => _ErrorView(message: e.toString()),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              Text(
                'Could not start MoneyFlow',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}