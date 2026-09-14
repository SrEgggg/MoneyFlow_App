import 'package:flutter/material.dart';
import 'calendar_tab.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Financial Calendar')),
    body: const CalendarTab(),
  );
}
