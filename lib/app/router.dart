import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/financial_day.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/goals/create_goal_screen.dart';
import '../features/goals/goal_detail_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/home/home_screen.dart';
import '../features/performance/achievements_screen.dart';
import '../features/performance/advanced_analytics_screen.dart';
import '../features/performance/day_detail_screen.dart';
import '../features/performance/monthly_review_screen.dart';
import '../features/performance/performance_screen.dart';
import '../features/performance/streaks_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transaction_detail_screen.dart';
import '../features/transactions/transactions_screen.dart';
import 'shell_scaffold.dart';

/// Route paths used throughout the app.
class Routes {
  Routes._();
  static const home = '/';
  static const transactions = '/transactions';
  static const goals = '/goals';
  static const performance = '/performance';
  static const settings = '/settings';

  static const createGoal = '/goals/new';
  static String goalDetail(int id) => '/goals/$id';
  static const accounts = '/accounts';
  static const budgets = '/settings/budgets';
  static const recurring = '/settings/recurring';
  static const performanceAchievements = '/performance/achievements';
  static const performanceStreaks = '/performance/streaks';
  static const performanceAdvanced = '/performance/advanced';
  static String performanceDay(DateTime d) =>
      '/performance/day/${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String performanceMonth(int year, int month) =>
      '/performance/review/$year/${month.toString().padLeft(2, '0')}';

  static String transactionDetail(int id) => '/transactions/$id';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (c, s) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'accounts',
                    builder: (c, s) => const AccountsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (c, s) => const TransactionsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (c, s) {
                      final id = int.tryParse(s.pathParameters['id'] ?? '');
                      if (id == null) return const SizedBox.shrink();
                      return TransactionDetailScreen(transactionId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.goals,
                builder: (c, s) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const CreateGoalScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) {
                      final id = int.tryParse(s.pathParameters['id'] ?? '');
                      if (id == null) return const SizedBox.shrink();
                      return GoalDetailScreen(goalId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.performance,
                builder: (c, s) => const PerformanceScreen(),
                routes: [
                  GoRoute(
                    path: 'achievements',
                    builder: (c, s) => const AchievementsScreen(),
                  ),
                  GoRoute(
                    path: 'streaks',
                    builder: (c, s) => const StreaksScreen(),
                  ),
                  GoRoute(
                    path: 'advanced',
                    builder: (c, s) => const AdvancedAnalyticsScreen(),
                  ),
                  GoRoute(
                    path: 'day/:date',
                    builder: (c, s) {
                      final raw = s.pathParameters['date'] ?? '';
                      final parts = raw.split('-');
                      if (parts.length != 3) return const SizedBox.shrink();
                      final d = DateTime(
                        int.tryParse(parts[0]) ?? 0,
                        int.tryParse(parts[1]) ?? 1,
                        int.tryParse(parts[2]) ?? 1,
                      );
                      return DayDetailScreen(
                        date: d,
                        financialDay: FinancialDay.key(d),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'review/:year/:month',
                    builder: (c, s) {
                      final y = int.tryParse(s.pathParameters['year'] ?? '');
                      final m = int.tryParse(s.pathParameters['month'] ?? '');
                      if (y == null || m == null) {
                        return const SizedBox.shrink();
                      }
                      return MonthlyReviewScreen(month: DateTime(y, m, 1));
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (c, s) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'budgets',
                    builder: (c, s) => const BudgetsScreen(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (c, s) => const RecurringScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
