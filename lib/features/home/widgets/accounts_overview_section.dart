import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

/// Inline preview of the user's accounts on the Home screen. Shows the type
/// chips with totals, then up to 3 most-recently-updated accounts as rows
/// inside a single section card.
class AccountsOverviewSection extends ConsumerWidget {
  const AccountsOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const _EmptyAccounts();
        }

        // Group totals.
        final totals = <AccountType, double>{};
        final byType = <AccountType, List<AccountRecord>>{};
        for (final t in AccountType.values) {
          byType[t] = [];
        }
        for (final a in accounts) {
          final t = AccountType.fromId(a.type);
          totals[t] = (totals[t] ?? 0) + a.balance;
          byType[t]!.add(a);
        }
        final types = totals.entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Pick up to three highest-balance accounts for the row preview.
        final previewRows = (accounts.toList()
              ..sort((a, b) => b.balance.compareTo(a.balance)))
            .take(3)
            .toList();

        return SectionCard(
          title: 'Accounts',
          subtitle: 'Across ${types.length} ${types.length == 1 ? 'type' : 'types'}',
          titleIcon: Icons.account_balance_outlined,
          titleIconColor: AppColors.primary,
          trailing: _SeeAllPill(onTap: () => context.go(Routes.accounts)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in types)
                    _TypeChip(type: e.key, total: e.value),
                ],
              ),
              if (previewRows.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.outline.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < previewRows.length; i++) ...[
                  _PremiumAccountRow(account: previewRows[i]),
                  if (i < previewRows.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
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
            ],
          ),
        );
      },
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Accounts',
      subtitle: 'Connect bank, e-wallet, and cash balances',
      titleIcon: Icons.account_balance_outlined,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(Routes.accounts),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Text(
                  'Add your first account',
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

class _TypeChip extends StatelessWidget {
  final AccountType type;
  final double total;
  const _TypeChip({required this.type, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: type.color.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, color: type.color, size: 13),
          const SizedBox(width: 6),
          Text(
            '${type.label} · ${Money.compact(total)}',
            style: TextStyle(
              color: type.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAccountRow extends StatelessWidget {
  final AccountRecord account;
  const _PremiumAccountRow({required this.account});

  Color _hexColor() {
    final raw = account.color.replaceAll('#', '');
    final v = int.tryParse('FF$raw', radix: 16);
    return v == null
        ? AccountType.fromId(account.type).color
        : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexColor();
    final type = AccountType.fromId(account.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(Routes.accounts),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(type.icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated ${D.shortDate(DateTime.now())}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.format(account.balance),
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant, size: 18),
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
