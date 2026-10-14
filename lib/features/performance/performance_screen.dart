import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import 'package:flutter/material.dart';
import 'calendar_tab.dart';
import 'performance_summary.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Performance tools',
            onSelected: (route) => context.push(route),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: Routes.performanceJournal,
                child: Text('Journal'),
              ),
              PopupMenuItem(
                value: Routes.performanceReviews,
                child: Text('Monthly reviews'),
              ),
              PopupMenuItem(
                value: Routes.performanceStreaks,
                child: Text('Streaks'),
              ),
              PopupMenuItem(
                value: Routes.performanceAchievements,
                child: Text('Achievements'),
              ),
              PopupMenuItem(
                value: Routes.performanceAdvanced,
                child: Text('Advanced analytics'),
              ),
            ],
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Calendar'),
          ],
        ),
      ),
      body: const TabBarView(children: [PerformanceSummary(), CalendarTab()]),
    ),
  );
}
