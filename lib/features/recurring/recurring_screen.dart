import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../data/models/budget.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';
import 'widgets/recurring_form.dart';

/// Recurring transaction rules. Each rule materializes one transaction per
/// occurrence on its cadence (daily / weekly / monthly); the runner advances
/// `nextRunAt` after each successful post.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            tooltip: 'Add rule',
            onPressed: () => _editRule(context, ref, null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) {
          if (rules.isEmpty) return const _EmptyState();
          return _RecurringBody(
            rules: rules,
            onEdit: (r) => _editRule(context, ref, r),
            running: _running,
            onRunAll: _runAll,
          );
        },
      ),
    );
  }

  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref,
    RecurringTransactionRecord? existing,
  ) async {
    final accounts = ref
        .read(accountsProvider)
        .maybeWhen<List<AccountRecord>>(
          data: (a) => a,
          orElse: () => const <AccountRecord>[],
        );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => RecurringForm(existing: existing, accounts: accounts),
    );
    if (saved != true) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        content: Text(
          existing == null ? 'Rule added' : 'Rule updated',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final count = await ref.read(recurringRunnerProvider).materializeDue();
      ref.read(recurringIssueProvider.notifier).state = null;
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(recurringProvider);
      ref.invalidate(streaksProvider);
      ref.invalidate(earnedAchievementsProvider);
      await ref
          .read(recalcServiceProvider)
          .recomputeAll(
            cutoffHour: (await ref.read(settingsProvider.future)).cutoffHour,
          );
      ref.invalidate(dailyCacheForMonthProvider);
      ref.invalidate(dailyCacheForDayProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          content: Text(
            count == 0
                ? 'Nothing to run right now.'
                : 'Posted $count ${count == 1 ? "transaction" : "transactions"}.${count >= 1000 ? " Run again to check remaining overdue dates." : ""}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    } catch (e) {
      ref.read(recurringIssueProvider.notifier).state =
          'Could not finish scheduled posting. Review the rules and retry.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(
            'Run failed: $e',
            style: const TextStyle(color: AppColors.onPrimary),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }
}

class _RecurringBody extends StatelessWidget {
  final List<RecurringTransactionRecord> rules;
  final void Function(RecurringTransactionRecord) onEdit;
  final bool running;
  final Future<void> Function() onRunAll;

  const _RecurringBody({
    required this.rules,
    required this.onEdit,
    required this.running,
    required this.onRunAll,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _RunAllCard(running: running, onTap: onRunAll),
        const SizedBox(height: 16),
        for (final r in rules) ...[
          _RecurringTile(rule: r, onTap: () => onEdit(r)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RunAllCard extends StatelessWidget {
  final bool running;
  final Future<void> Function() onTap;
  const _RunAllCard({required this.running, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: running ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: running
                    ? Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Run due rules now',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Posts overdue dates through today, up to 1,000 per run.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringTransactionRecord rule;
  final VoidCallback onTap;
  const _RecurringTile({required this.rule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = rule.isActive;
    final typeColor = rule.type == TxType.income
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final lastRun = rule.lastRunAt;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      rule.type == TxType.income
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rule.cadenceLabel} · ${rule.type == TxType.income ? 'Income' : 'Expense'}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${rule.type == TxType.income ? '+' : '-'}${Money.of(context).format(rule.amount)}',
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.18)
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          active ? 'Active' : 'Paused',
                          style: TextStyle(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Next: ${D.fullDate(rule.nextRunAt)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (lastRun != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Last: ${D.fullDate(lastRun)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.autorenew_rounded,
                color: Color(0xFF8B5CF6),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No recurring rules',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set up salary, rent, or subscriptions and they post automatically on their schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
