import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/money.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../../providers.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_form.dart';

/// Per-category spending caps. Lists the budgets that apply to the current
/// month (plus any rolling ones with `monthKey == null`), each rendered with
/// a progress bar against the user's spend in that category so far.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final repo = ref.watch(budgetRepoProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'Add budget',
            onPressed: () => _editBudget(context, ref, null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.onSurfaceVariant)),
        ),
        data: (budgets) => _BudgetBody(
          budgets: budgets,
          repo: repo,
          anchor: now,
          onEdit: (b) => _editBudget(context, ref, b),
        ),
      ),
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    BudgetRecord? existing,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => BudgetForm(existing: existing),
    );
    if (saved != true) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        content: Text(
          existing == null ? 'Budget added' : 'Budget updated',
          style: const TextStyle(color: AppColors.onSurface),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  final List<BudgetRecord> budgets;
  final BudgetRepo repo;
  final DateTime anchor;
  final void Function(BudgetRecord) onEdit;

  const _BudgetBody({
    required this.budgets,
    required this.repo,
    required this.anchor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const _EmptyState();

    return FutureBuilder<Map<String, double>>(
      future: repo.spendByCategoryForMonth(anchor),
      builder: (context, snap) {
        final spent = snap.data ?? const <String, double>{};
        // Sort: exceeded first (by overrun), then by spent descending.
        final ordered = [...budgets]..sort((a, b) {
            final aSpent = spent[a.category] ?? 0;
            final bSpent = spent[b.category] ?? 0;
            final aOver = aSpent - a.amount;
            final bOver = bSpent - b.amount;
            if (aOver > 0 && bOver <= 0) return -1;
            if (bOver > 0 && aOver <= 0) return 1;
            if (aOver > 0 && bOver > 0) return bOver.compareTo(aOver);
            return bSpent.compareTo(aSpent);
          });
        final totalCap = budgets.fold<double>(0, (s, b) => s + b.amount);
        final totalSpent =
            budgets.fold<double>(0, (s, b) => s + (spent[b.category] ?? 0));

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: _BudgetSummary(
                  cap: totalCap,
                  spent: totalSpent,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: ordered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final b = ordered[i];
                  final s = spent[b.category] ?? 0;
                  return BudgetCard(
                    budget: b,
                    spent: s,
                    onTap: () => onEdit(b),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  final double cap;
  final double spent;
  const _BudgetSummary({required this.cap, required this.spent});

  @override
  Widget build(BuildContext context) {
    final remaining = cap - spent;
    final pct = cap > 0 ? (spent / cap).clamp(0.0, 1.5) : 0.0;
    final over = remaining < 0;
    final progressColor = over
        ? AppColors.error
        : pct > 0.85
            ? const Color(0xFFEAB308)
            : AppColors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  over
                      ? Icons.warning_amber_rounded
                      : Icons.savings_outlined,
                  size: 18,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Total this month',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                over
                    ? 'Over ${Money.format((spent - cap).abs())}'
                    : '${Money.format(remaining)} left',
                style: TextStyle(
                  color: over
                      ? AppColors.error
                      : AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: 'Spent',
                value: Money.format(spent),
                color: AppColors.onSurface,
              ),
              const SizedBox(width: 18),
              _MiniStat(
                label: 'Cap',
                value: Money.format(cap),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceContainerHigh),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
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
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.pie_chart_outline_rounded,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'No budgets yet',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set monthly caps per category to keep spending in check.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
