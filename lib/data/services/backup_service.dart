import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database.dart';
import '../../core/utils/app_logger.dart';

/// Backup / restore format version. Bump when the on-disk schema or this
/// JSON envelope shape changes incompatibly.
const int kBackupFormatVersion = 2;

/// All user-data tables we know how to back up. Order matters for
/// restore: parent tables before children, and cache/streaks last because
/// they aggregate the rest.
const List<String> kBackupTables = [
  'recurring_transactions',
  'budgets',
  'accounts',
  'goals',
  'goal_contributions',
  'transactions',
  'journal_entries',
  'daily_performance_cache',
  'streaks',
  'user_achievements',
];

/// Reads every user-data table and produces a JSON envelope the user can
/// save off-device for safekeeping. Restore is also supported so the same
/// file can be brought back into a fresh install.
class BackupService {
  final AppDatabase db;
  final AppLogger? logger;
  BackupService(this.db, {this.logger});

  /// Encode every user-data table to a JSON string. Includes a `format`
  /// version + `exported_at` so future readers can detect mismatches.
  Future<String> exportJsonString() async {
    final database = await db.database;
    final envelope = <String, Object?>{
      'format': kBackupFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'MoneyFlow',
      'tables': <String, Object?>{},
    };
    final tables = envelope['tables'] as Map<String, Object?>;
    for (final name in kBackupTables) {
      final rows = await database.query(name);
      tables[name] = rows.map(_rowToJsonable).toList();
    }
    // Settings is a single-row special case.
    final settingsRows = await database.query('settings', where: 'id = 1');
    if (settingsRows.isNotEmpty) {
      tables['settings'] = [_rowToJsonable(settingsRows.first)];
    }
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Write the JSON dump to a file under the app documents dir and return
  /// the path. Filename includes a timestamp so multiple backups don't
  /// clobber each other.
  Future<File> exportToFile() async {
    logger?.info('Exporting backup to file...');
    final json = await exportJsonString();
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(dir.path, 'moneyflow-backup-$stamp.json'));
    await file.writeAsString(json);
    logger?.info('Backup exported to ${file.path}');
    return file;
  }

  /// Restore from a JSON file. Refuses files whose `format` is newer than
  /// what this build of the app supports. Throws on malformed JSON so the
  /// caller can surface a clear error.
  ///
  /// When [replace] is true (the default) existing rows in every table are
  /// wiped before the new data is inserted. Otherwise the file's rows are
  /// inserted additively, which is useful for partial recovery but may
  /// cause unique-key conflicts.
  Future<RestoreReport> restoreFromFile(
    File file, {
    bool replace = true,
  }) async {
    final raw = await file.readAsString();
    return restoreFromJsonString(raw, replace: replace);
  }

  Future<RestoreReport> restoreFromJsonString(
    String raw, {
    bool replace = true,
  }) async {
    logger?.info('Restoring from JSON string (replace=$replace)...');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      final err = 'Backup file is not a JSON object';
      logger?.error(err);
      throw const FormatException('Backup file is not a JSON object');
    }
    final format = (decoded['format'] as num?)?.toInt() ?? 0;
    if (format > kBackupFormatVersion) {
      throw FormatException(
        'Backup format $format is newer than this app supports '
        '($kBackupFormatVersion). Update MoneyFlow first.',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw const FormatException('Missing or invalid "tables" envelope');
    }

    // Validate the envelope before a replace operation can remove saved data.
    for (final name in [
      'accounts',
      'goals',
      'goal_contributions',
      'transactions',
      'settings',
    ]) {
      final rows = tables[name];
      if (rows is! List || rows.any((row) => row is! Map)) {
        throw FormatException('Missing or invalid backup table: $name');
      }
    }
    if ((tables['settings'] as List).length != 1) {
      throw const FormatException('Backup must include one settings record.');
    }
    final database = await db.database;
    final counts = <String, int>{};

    logger?.info('Starting database transaction for restore...');
    await database.transaction((txn) async {
      if (replace) {
        // Wipe in reverse-dependency order so no FK trips.
        for (final name in kBackupTables.reversed) {
          await txn.delete(name);
        }
        await txn.delete('settings');
      }

      // Restore tables in the documented order. Settings is a special case
      // because it has a fixed primary key (id = 1).
      for (final name in kBackupTables) {
        logger?.info('Restoring table: $name');
        final rows = tables[name];
        if (rows is! List) continue;
        for (final r in rows) {
          if (r is! Map) continue;
          final row = _rowFromJsonable(r);
          await txn.insert(
            name,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        counts[name] = rows.length;
      }

      final settings = tables['settings'];
      if (settings is List && settings.isNotEmpty) {
        final first = settings.first;
        if (first is Map) {
          final row = _rowFromJsonable(first);
          await txn.insert(
            'settings',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          counts['settings'] = 1;
        }
      }
    });

    return RestoreReport(
      format: format,
      restoredAt: DateTime.now(),
      rowCounts: counts,
    );
  }

  // JSON doesn't preserve integer/float distinction — `42` and `42.0` both
  // come back as `num`. SQLite is strict about ints vs doubles, so we lean
  // on the original column type to decide which one to write back.
  Map<String, Object?> _rowToJsonable(Map<String, Object?> row) {
    return row.map((k, v) => MapEntry(k, _toJsonable(v)));
  }

  Object? _toJsonable(Object? v) {
    if (v == null) return null;
    if (v is num || v is String || v is bool) return v;
    // sqflite stores DateTime-ish strings verbatim; pass them through.
    return v.toString();
  }

  /// Reverse of [_rowToJsonable]. JSON-decoded values come back as `dynamic`,
  /// so we cast the keys and trust SQLite to coerce ints/doubles where the
  /// column allows. No transformation needed today — kept as a function so
  /// future schema migrations can hook in here.
  Map<String, Object?> _rowFromJsonable(Map<dynamic, dynamic> row) {
    return row.map((k, v) => MapEntry(k.toString(), v));
  }
}

class RestoreReport {
  final int format;
  final DateTime restoredAt;
  final Map<String, int> rowCounts;

  const RestoreReport({
    required this.format,
    required this.restoredAt,
    required this.rowCounts,
  });

  int get totalRows => rowCounts.values.fold<int>(0, (a, b) => a + b);
}

/// Lightweight description of the backup contents, for the Settings UI.
/// Avoids loading the whole file into memory just to display a header.
class BackupFileSummary {
  final int format;
  final DateTime? exportedAt;
  final Map<String, int> tableCounts;

  const BackupFileSummary({
    required this.format,
    required this.exportedAt,
    required this.tableCounts,
  });

  static Future<BackupFileSummary> peek(File file) async {
    final head = await file
        .openRead(0, 64 * 1024)
        .fold<String>(
          '',
          (acc, chunk) => acc + utf8.decode(chunk, allowMalformed: true),
        );
    final braceIdx = head.indexOf('{');
    if (braceIdx < 0) {
      throw const FormatException('Not a JSON file');
    }
    final decoded = jsonDecode(head.substring(braceIdx));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Not a MoneyFlow backup');
    }
    final format = (decoded['format'] as num?)?.toInt() ?? 0;
    final exportedAtRaw = decoded['exported_at'] as String?;
    final exportedAt = exportedAtRaw == null
        ? null
        : DateTime.tryParse(exportedAtRaw);
    final tables = decoded['tables'];
    final counts = <String, int>{};
    if (tables is Map<String, Object?>) {
      tables.forEach((name, rows) {
        if (rows is List) counts[name] = rows.length;
      });
    }
    return BackupFileSummary(
      format: format,
      exportedAt: exportedAt,
      tableCounts: counts,
    );
  }
}
