import 'package:flutter/material.dart';

import '../../app/theme.dart';

class DayDetailScreen extends StatelessWidget {
  final DateTime date;
  final DateTime financialDay;
  const DayDetailScreen({
    super.key,
    required this.date,
    required this.financialDay,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$date.year-${date.month}-${date.day}')),
      body: const Center(
        child: Text('Day detail coming up',
            style: TextStyle(color: AppColors.onSurface)),
      ),
    );
  }
}
