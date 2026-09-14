import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../performance/widgets/activity_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_card.dart';
import '../../providers.dart';
import 'providers/home_providers.dart';
import 'widgets/accounts_overview_section.dart';
import 'widgets/active_goals_list.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/smart_insights_list.dart';
import 'widgets/streaks_summary_row.dart';
import 'widgets/total_savings_card.dart';

/// Home dashboard.
///
/// Top-down layout, all sections collapsible-on-empty:
/// 1. App bar (menu + greeting + notification bell)
/// 2. Personalized greeting block
/// 3. Total Savings hero card (sum of all accounts + sparkline)
/// 4. Monthly progress ring card
/// 5. Accounts overview (chips + top accounts)
/// 6. Recent transactions (last 5)
/// 7. Active goals
/// 8. Smart insights
/// 9. Streaks summary
///
/// Privacy: every figure is derived from data the user entered manually.
/// No external API is consulted. The app starts completely empty.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _hasNotificationDot = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _hasNotificationDot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceContainer,
        onRefresh: () async {
          ref.invalidate(homeSummaryProvider);
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          await ref.read(homeSummaryProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 56,
              titleSpacing: 16,
              title: const _MenuButton(),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: _hasNotificationDot,
                  builder: (_, hasDot, __) => _BellButton(
                    hasDot: hasDot,
                    onTap: () => _hasNotificationDot.value = false,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  if (ref.watch(recurringIssueProvider) case final String issue)
                    SectionCard(
                      title: 'Scheduled transactions need attention',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue),
                          TextButton(
                            onPressed: () => context.go(Routes.recurring),
                            child: const Text('Review recurring rules'),
                          ),
                        ],
                      ),
                    ),
                  const _Greeting(),
                  const SizedBox(height: 18),
                  const TotalSavingsCard(),
                  const SizedBox(height: 14),
                  const _MonthlyProgressCard(),
                  const SizedBox(height: 14),
                  const AccountsOverviewSection(),
                  const SizedBox(height: 14),
                  const RecentTransactionsCard(),
                  const SizedBox(height: 14),
                  const ActiveGoalsList(),
                  const SizedBox(height: 14),
                  const SmartInsightsList(),
                  const SizedBox(height: 14),
                  const FinancialActivityCard(),
                  const SizedBox(height: 14),
                  const StreaksSummaryRow(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Scaffold.of(context).openDrawer(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.menu_rounded, color: AppColors.onSurface, size: 20),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasDot;
  final VoidCallback onTap;
  const _BellButton({required this.hasDot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.onSurface,
                size: 20,
              ),
              if (hasDot)
                const Positioned(top: 10, right: 10, child: _NotificationDot()),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceContainer, width: 2),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref
        .watch(settingsProvider)
        .maybeWhen(data: (s) => s.displayName, orElse: () => 'there');
    final display =
        (name.trim().isEmpty || name.trim().toLowerCase() == 'there')
        ? 'there'
        : name.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, $display! 👋',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Here's your financial overview",
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyProgressCard extends ConsumerWidget {
  const _MonthlyProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);
    return summaryAsync.when(
      loading: () => const _LoadingCard(height: 130),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (s) {
        final pct = s.monthlyGoal > 0
            ? (s.monthlySaved / s.monthlyGoal).clamp(0.0, 1.0)
            : 0.0;
        final now = DateTime.now();
        final monthLabel = D.shortMonthYear(DateTime(now.year, now.month, 1));
        final daysLeft = D.daysInMonth(now) - now.day;
        return SectionCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Goal Savings',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              monthLabel,
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'Contributed',
                              value: Money.format(s.monthlySaved),
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MiniStat(
                              label: 'Goal',
                              value: s.monthlyGoal > 0
                                  ? Money.format(s.monthlyGoal)
                                  : 'Not set',
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            children: [
                              Container(color: AppColors.surfaceContainerHigh),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF16A34A),
                                        Color(0xFF22C55E),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        daysLeft == 0
                            ? 'Last day of $monthLabel'
                            : '$daysLeft ${daysLeft == 1 ? "day" : "days"} left in $monthLabel',
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ProgressRing(
                  progress: pct,
                  centerText: '${(pct * 100).round()}%',
                  size: 80,
                  stroke: 8,
                  progressColor: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
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
            letterSpacing: 0.2,
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

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
