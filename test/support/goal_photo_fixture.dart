import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Uint8List> sampleImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1200, 800),
    Paint()..color = const Color(0xFF15803D),
  );
  canvas.drawRect(
    const Rect.fromLTWH(160, 140, 880, 520),
    Paint()..color = const Color(0xFF222631),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1200, 800);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
