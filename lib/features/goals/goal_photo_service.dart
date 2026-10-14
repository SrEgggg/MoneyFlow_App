import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/goal_photo_data.dart';

final goalPhotoServiceProvider = Provider((ref) => GoalPhotoService());
final recoveredGoalPhotoProvider = FutureProvider<String?>(
  (ref) => ref.read(goalPhotoServiceProvider).recover(),
);

class GoalPhotoService {
  final ImagePicker picker;
  GoalPhotoService({ImagePicker? picker}) : picker = picker ?? ImagePicker();
  Future<String?> pick() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file == null ? null : _read(file);
  }

  Future<String?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    return files == null || files.isEmpty ? null : _read(files.first);
  }

  Future<String> _read(XFile file) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 20 MB.');
    }
    return prepare(await file.readAsBytes());
  }

  /// Re-encoding removes source metadata and keeps the database row bounded.
  static Future<String> prepare(Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Photo is too large.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      for (final limit in [768, 576, 384]) {
        final ratio = longest > limit ? limit / longest : 1.0;
        final codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * ratio).round().clamp(1, 768),
          targetHeight: (descriptor.height * ratio).round().clamp(1, 768),
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final data = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data != null && data.lengthInBytes <= GoalPhotoData.maxBytes) {
              return base64Encode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              );
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
      throw const FormatException('Choose a simpler or smaller photo.');
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
