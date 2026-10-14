import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupFilesProvider = Provider((ref) => BackupFiles());

class SelectedBackup {
  final String name;
  final String json;
  const SelectedBackup(this.name, this.json);
}

/// Native dialogs, separated from database logic for cancellation/UI tests.
class BackupFiles {
  Future<bool> save(String json) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save MoneyFlow backup',
      fileName:
          'moneyflow-backup-${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path == null) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  Future<SelectedBackup?> pick() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose MoneyFlow backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 64 * 1024 * 1024) {
      throw const FormatException('Choose a backup smaller than 64 MB.');
    }
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    return SelectedBackup(file.name, utf8.decode(bytes));
  }
}
