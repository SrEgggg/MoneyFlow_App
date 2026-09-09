import 'package:flutter/material.dart';

/// Journal mood options. One per business day.
class MoodOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const MoodOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class Moods {
  Moods._();

  static const List<MoodOption> all = [
    MoodOption(
      id: 'excellent',
      label: 'Excellent',
      icon: Icons.sentiment_very_satisfied,
      color: Color(0xFF22C55E),
    ),
    MoodOption(
      id: 'good',
      label: 'Good',
      icon: Icons.sentiment_satisfied,
      color: Color(0xFF84CC16),
    ),
    MoodOption(
      id: 'neutral',
      label: 'Neutral',
      icon: Icons.sentiment_neutral,
      color: Color(0xFFEAB308),
    ),
    MoodOption(
      id: 'bad',
      label: 'Bad',
      icon: Icons.sentiment_dissatisfied,
      color: Color(0xFFF97316),
    ),
    MoodOption(
      id: 'stress',
      label: 'Stress',
      icon: Icons.mood_bad,
      color: Color(0xFFEF4444),
    ),
  ];

  static MoodOption byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => all[2]);
}
