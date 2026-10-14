import 'dart:convert';
import 'dart:typed_data';

/// A small, portable photo keeps goal rows and backups self-contained.
abstract final class GoalPhotoData {
  static const maxBytes = 384 * 1024;
  static Uint8List? decode(String? value) {
    if (value == null) return null;
    if (value.length > maxBytes * 4 ~/ 3 + 4) {
      throw const FormatException('Goal photo is too large.');
    }
    final bytes = base64Decode(value);
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length > maxBytes ||
        bytes.length < 24 ||
        !List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      throw const FormatException('Goal photo must be a valid PNG.');
    }
    final data = ByteData.sublistView(bytes);
    final width = data.getUint32(16), height = data.getUint32(20);
    if (width == 0 || height == 0 || width > 768 || height > 768) {
      throw const FormatException('Goal photo dimensions are unsupported.');
    }
    return bytes;
  }
}
