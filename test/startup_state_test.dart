import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savings_app/app/theme.dart';
import 'package:savings_app/core/widgets/startup_state.dart';

void main() {
  testWidgets('startup error fits large text and offers a working retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: StartupFailure(onRetry: () => retries++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      expect(tester.takeException(), isNull);
    }
    expect(retries, 2);
  });

  testWidgets('startup loading includes brand and accessible progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const StartupLoading()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('MoneyFlow'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .semanticsLabel,
      'Loading MoneyFlow',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
