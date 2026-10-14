import 'package:flutter/material.dart';

/// Shared mobile layout tokens. Use 4 only for tight label/icon alignment.
abstract final class AppSpace {
  static const xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0;
  static const page = EdgeInsets.fromLTRB(md, md, md, xl);
}

abstract final class AppRadius {
  static const control = 12.0, card = 16.0, sheet = 24.0;
}

abstract final class AppMotion {
  static Duration duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
}

class LoadingPlaceholder extends StatelessWidget {
  final int lines;
  const LoadingPlaceholder({super.key, this.lines = 3});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: FractionallySizedBox(
                widthFactor: i == 0 ? .5 : 1,
                child: Container(
                  height: i == 0 ? 24 : 16,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class InlineNotice extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  const InlineNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

/// Keeps asynchronous controls disabled until they finish, including dialogs.
class AsyncAction extends StatefulWidget {
  final Future<void> Function() action;
  final Widget Function(bool busy, VoidCallback run) builder;
  const AsyncAction({super.key, required this.action, required this.builder});
  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool _busy = false;
  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_busy, _run);
}
