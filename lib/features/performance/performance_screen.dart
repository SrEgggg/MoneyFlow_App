import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: const EmptyState(
        icon: Icons.bar_chart,
        title: 'Performance coming up…',
      ),
    );
  }
}
