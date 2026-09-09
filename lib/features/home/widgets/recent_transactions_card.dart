import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

/// Last 5 transactions on Home. Tapping a row routes to the full
/// Transactions tab; "See all" routes to the same place.
class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);

    return txsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (txs) {
        if (txs.isEmpty) return _EmptyRecent();
        final top5 = txs.take(5).toList();
        return SectionCard(
          title: 'Recent Transactions',
          subtitle: 'Last ${top5.length}',
          titleIcon: Icons.receipt_long_rounded,
          titleIconColor: AppColors.primary,
          trailing: _SeeAllPill(onTap: () => context.go(Routes.transactions)),
          child: Column(
            children: [
              for (int i = 0; i < top5.length; i++) ...[
                _TxRow(tx: top5[i]),
                if (i < top5.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.outline.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Transactions',
      subtitle: 'Nothing yet — log your first transaction',
      titleIcon: Icons.receipt_long_rounded,
      titleIconColor: AppColors.primary,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(Routes.transactions),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Text(
                  'Log your first transaction',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TxRecord tx;
  const _TxRow({required this.tx});

  TxCategory _category() => Categories.byId(tx.category);

  @override
  Widget build(BuildContext context) {
    final category = _category();
    final color = category.color;
    final income = tx.type == TxType.income;
    final categoryLabel = category.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(Routes.transactions),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(category.icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.notes?.isNotEmpty == true
                          ? tx.notes!
                          : categoryLabel,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoryLabel · ${tx.account}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      D.relativeDay(tx.occurredAt),
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${income ? '+' : '-'}${Money.format(tx.amount.abs())}',
                style: TextStyle(
                  color: income ? AppColors.primary : AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
