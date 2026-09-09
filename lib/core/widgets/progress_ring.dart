import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Circular percent indicator used in the Home monthly-progress card.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final String centerText;
  final TextStyle? centerStyle;
  final double size;
  final double stroke;
  final Color trackColor;
  final Color progressColor;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.centerText,
    this.centerStyle,
    this.size = 84,
    this.stroke = 8,
    this.trackColor = AppColors.surfaceContainerHigh,
    this.progressColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: stroke,
              color: trackColor,
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: stroke,
              color: progressColor,
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            centerText,
            style: centerStyle ??
                const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Linear progress bar (used in goal cards and active goals list).
class LinearProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color color;
  final Color trackColor;
  const LinearProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color = AppColors.primary,
    this.trackColor = AppColors.surfaceContainerHigh,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: trackColor),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}