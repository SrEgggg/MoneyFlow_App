import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/constants/categories.dart';
import '../database/database.dart';

class CategoryRepository {
  final AppDatabase db;
  CategoryRepository(this.db);

  Future<List<TxCategory>> all() async {
    final rows = await (await db.database).query(
      'custom_categories',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (r) => TxCategory(
            id: r['id'] as String,
            name: r['name'] as String,
            kind: r['kind'] as String,
            archived: r['is_archived'] == 1,
            icon: customCategoryIcons[r['icon_key']] ?? Icons.label_outline,
            color: Color(r['color_value'] as int),
          ),
        )
        .toList();
  }

  Future<TxCategory> create(
    String name,
    String kind, {
    String iconKey = 'label',
    Color color = const Color(0xFF3B82F6),
    String? existingId,
  }) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalized = clean.toLowerCase();
    if (clean.isEmpty || clean.length > 32) {
      throw const FormatException(
        'Enter a category name of 1 to 32 characters.',
      );
    }
    if (kind != 'income' && kind != 'expense') {
      throw const FormatException('Choose income or expense.');
    }
    if (!customCategoryIcons.containsKey(iconKey) ||
        !customCategoryColors.contains(color)) {
      throw const FormatException('Choose an available icon and color.');
    }
    final builtIns = [
      ...Categories.income,
      ...Categories.expense,
      Categories.byId('transfer'),
    ];
    if (builtIns.any((c) => c.name.toLowerCase() == normalized)) {
      throw const FormatException(
        'That category already exists. Choose it from the list.',
      );
    }
    final id =
        existingId ??
        'custom_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await (await db.database).transaction((txn) async {
      final existing = await txn.query(
        'custom_categories',
        where: 'normalized_name = ? AND id != ?',
        whereArgs: [normalized, id],
      );
      if (existing.isNotEmpty) {
        throw const FormatException(
          'That category already exists. Choose it from the list.',
        );
      }
      final row = <String, Object?>{
        'id': id,
        'name': clean,
        'normalized_name': normalized,
        'kind': kind,
        'icon_key': iconKey,
        'color_value': color.toARGB32(),
      };
      if (existingId == null) {
        await txn.insert('custom_categories', row);
      } else {
        final updated = await txn.update(
          'custom_categories',
          row,
          where: 'id = ? AND kind = ? AND is_archived = 0',
          whereArgs: [id, kind],
        );
        if (updated != 1) {
          throw const FormatException(
            'This category is no longer available. Reopen the category list.',
          );
        }
      }
    });
    return TxCategory(
      id: id,
      name: clean,
      kind: kind,
      icon: customCategoryIcons[iconKey]!,
      color: color,
    );
  }

  /// Remove from future pickers without changing any historical references.
  Future<void> remove(String id) async {
    await (await db.database).update(
      'custom_categories',
      {'is_archived': 1, 'normalized_name': 'archived:$id'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
