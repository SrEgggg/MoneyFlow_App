import 'package:flutter/material.dart';
import 'app_ui.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 72});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: Image.asset(
      'assets/brand/play-store-icon.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}

class StartupLoading extends StatelessWidget {
  const StartupLoading({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 96),
              const SizedBox(height: AppSpace.md),
              Text(
                'MoneyFlow',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Opening your money overview',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.lg),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  semanticsLabel: 'Loading MoneyFlow',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StartupFailure extends StatelessWidget {
  final VoidCallback onRetry;
  const StartupFailure({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Could not open MoneyFlow',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Your saved data could not be loaded. Try again. If this continues, close and reopen the app; do not uninstall it or clear its storage.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
