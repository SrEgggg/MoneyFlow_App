import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/utils/goal_photo_data.dart';

/// Consistent photo treatment; malformed/unsupported images retain an icon.
class GoalImage extends StatefulWidget {
  final String? photo;
  final IconData icon;
  final double size;
  const GoalImage({super.key, this.photo, required this.icon, this.size = 56});
  @override
  State<GoalImage> createState() => _GoalImageState();
}

class _GoalImageState extends State<GoalImage> {
  Uint8List? _bytes;
  void _decode() {
    try {
      _bytes = GoalPhotoData.decode(widget.photo);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(GoalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) _decode();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          widget.icon,
          color: Theme.of(context).colorScheme.primary,
          size: widget.size * .42,
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: _bytes == null
              ? fallback
              : Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}
