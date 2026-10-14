import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/money_amount.dart';
import '../../core/utils/goal_photo_data.dart';
import '../models/enums.dart';

/// Validate the entire envelope before a replacement transaction starts.
Future<void> validateBackup(
  Database db,
  Map<String, Object?> tables,
  int format,
  List<String> knownTables,
) async {
  Never invalid(String table, String field) => throw FormatException(
    'Invalid backup: $table / $field. Your data has not been changed.',
  );
  if (tables['settings'] is! List || (tables['settings'] as List).length != 1) {
    invalid('settings', 'single settings row');
  }
  for (final table in [...knownTables, 'settings']) {
    final introduced = table == 'transaction_revisions'
        ? 7
        : table == 'custom_categories'
        ? 4
        : ['budgets', 'recurring_transactions'].contains(table)
        ? 2
        : 1;
    final rows = tables[table];
    if (rows == null && format < introduced) continue;
    if (rows is! List) invalid(table, 'missing table');
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final ids = <Object>{};
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) invalid(table, 'row');
      if (raw.keys.any((key) => !columns.any((c) => c['name'] == key))) {
        invalid(table, 'unknown field');
      }
      for (final column in columns) {
        final field = column['name'] as String;
        if (format >= 7 && !raw.containsKey(field)) {
          invalid(table, 'missing $field');
        }
        final value = raw[field];
        if (value == null) {
          if ((column['notnull'] == 1 && column['dflt_value'] == null) ||
              column['pk'] == 1) {
            invalid(table, field);
          }
          continue;
        }
        final type = column['type'];
        if (type == 'TEXT' && value is! String ||
            type == 'INTEGER' && value is! int ||
            type == 'REAL' && (value is! num || !value.isFinite)) {
          invalid(table, field);
        }
        if (column['pk'] == 1 &&
            (!ids.add(value) || value is int && value <= 0)) {
          invalid(table, 'duplicate/invalid ID');
        }
        if (field.endsWith('_at') ||
            [
              'date',
              'entry_date',
              'target_date',
              'start_date',
              'end_date',
              'last_qualified_day',
            ].contains(field)) {
          final date = DateTime.tryParse(value.toString());
          if (date == null) invalid(table, field);
          final match = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})',
          ).firstMatch(value.toString());
          if (match == null) invalid(table, field);
          final y = int.parse(match[1]!);
          final m = int.parse(match[2]!);
          final d = int.parse(match[3]!);
          final day = DateTime.utc(y, m, d);
          if (day.year != y || day.month != m || day.day != d) {
            invalid(table, field);
          }
        }
      }
      void money(String field, {bool signed = false, bool zero = false}) {
        if (raw[field] is! num ||
            !MoneyAmount.valid(raw[field] as num, signed: signed, zero: zero)) {
          invalid(table, field);
        }
      }

      void choice(String field, Iterable<String> choices) {
        if (!choices.contains(raw[field])) invalid(table, field);
      }

      for (final field in ['name', 'account', 'category', 'content']) {
        if (raw.containsKey(field) && (raw[field] as String).trim().isEmpty) {
          invalid(table, field);
        }
      }
      switch (table) {
        case 'accounts':
          money('balance', signed: true);
          choice('type', AccountType.values.map((v) => v.id));
        case 'transactions':
          money('amount');
          choice('type', TxType.values.map((v) => v.id));
          if (raw['type'] == 'transfer' &&
              (raw['destination_account'] == null ||
                  raw['account'] == raw['destination_account'])) {
            invalid(table, 'destination_account');
          }
        case 'goals':
          money('target_amount');
          money('current_amount', zero: true);
          if (raw['monthly_target'] != null) money('monthly_target');
          choice('kind', GoalKind.values.map((v) => v.id));
          choice('status', GoalStatus.values.map((v) => v.id));
          GoalPhotoData.decode(raw['photo'] as String?);
        case 'goal_contributions':
          money('amount', signed: true);
          if (raw['amount'] == 0) invalid(table, 'amount');
        case 'budgets':
          money('amount');
          if (raw['month_key'] != null &&
              !RegExp(
                r'^\d{4}-(0[1-9]|1[0-2])$',
              ).hasMatch(raw['month_key'] as String)) {
            invalid(table, 'month_key');
          }
        case 'recurring_transactions':
          money('amount');
          choice('type', ['income', 'expense']);
          choice('frequency', ['daily', 'weekly', 'monthly']);
          if ((raw['interval_count'] as int) < 1 ||
              (raw['interval_count'] as int) > 120) {
            invalid(table, 'interval_count');
          }
          if (![0, 1].contains(raw['is_active'])) invalid(table, 'is_active');
          if (raw['end_date'] != null &&
              DateTime.parse(
                raw['end_date'] as String,
              ).isBefore(DateTime.parse(raw['start_date'] as String))) {
            invalid(table, 'end_date');
          }
        case 'settings':
          if (rows.length != 1 || raw['id'] != 1) {
            invalid(table, 'single settings row');
          }
          if ((raw['display_name'] as String).trim().isEmpty) {
            invalid(table, 'display_name');
          }
          choice('currency', ['PHP', 'USD']);
          if (raw['theme_mode'] != null) {
            choice('theme_mode', ['system', 'dark', 'light']);
          }
          if ((raw['cutoff_hour'] as int) < 0 ||
              (raw['cutoff_hour'] as int) > 5) {
            invalid(table, 'cutoff_hour');
          }
        case 'custom_categories':
          choice('kind', ['income', 'expense']);
          if (raw['is_archived'] != null &&
              ![0, 1].contains(raw['is_archived'])) {
            invalid(table, 'is_archived');
          }
        case 'transaction_revisions':
          for (final field in ['old_values', 'new_values']) {
            if (jsonDecode(raw[field] as String) is! Map) invalid(table, field);
          }
      }
    }
  }
  final accountNames = <String>{};
  final normalized = <String>{};
  for (final row in tables['accounts'] as List) {
    final name = row['name'] as String;
    if (!normalized.add(name.trim().toLowerCase())) {
      invalid('accounts', 'duplicate names');
    }
    accountNames.add(name);
  }
  final goalIds = (tables['goals'] as List).map((r) => r['id']).toSet();
  for (final row in tables['goal_contributions'] as List) {
    if (!goalIds.contains(row['goal_id'])) {
      invalid('goal_contributions', 'goal reference');
    }
  }
  for (final table in ['transactions', 'recurring_transactions']) {
    for (final row in tables[table] as List? ?? []) {
      if (!accountNames.contains(row['account'])) {
        invalid(table, 'account reference');
      }
      if (row['type'] == 'transfer' &&
          !accountNames.contains(row['destination_account'])) {
        invalid(table, 'destination reference');
      }
    }
  }
  final categoryNames = <Object>{};
  for (final row in tables['custom_categories'] as List? ?? []) {
    if (!categoryNames.add(row['normalized_name'])) {
      invalid('custom_categories', 'duplicate name');
    }
  }
}
