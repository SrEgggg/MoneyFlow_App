import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Transaction category: icon, color, default kind.
class TxCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// 'income' or 'expense' — controls which side of Quick Add the
  /// category is shown in.
  final String kind;

  const TxCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
  });
}

/// Default categories seeded into the app. MoneyFlow focuses on expense
/// tracking; income is mostly salary and gifts.
class Categories {
  Categories._();

  static const List<TxCategory> expense = [
    TxCategory(
      id: 'personal',
      name: 'Personal',
      icon: Icons.person_outline,
      color: AppColors.primary,
      kind: 'expense',
    ),
    TxCategory(
      id: 'food_dining',
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: Color(0xFFF97316),
      kind: 'expense',
    ),
    TxCategory(
      id: 'transportation',
      name: 'Transportation',
      icon: Icons.directions_car,
      color: Color(0xFF3B82F6),
      kind: 'expense',
    ),
    TxCategory(
      id: 'groceries',
      name: 'Groceries',
      icon: Icons.shopping_basket,
      color: Color(0xFF84CC16),
      kind: 'expense',
    ),
    TxCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFEC4899),
      kind: 'expense',
    ),
    TxCategory(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long,
      color: Color(0xFFA855F7),
      kind: 'expense',
    ),
    TxCategory(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: Color(0xFF14B8A6),
      kind: 'expense',
    ),
    TxCategory(
      id: 'health',
      name: 'Health',
      icon: Icons.favorite,
      color: Color(0xFFEF4444),
      kind: 'expense',
    ),
    TxCategory(
      id: 'education',
      name: 'Education',
      icon: Icons.school,
      color: Color(0xFF6366F1),
      kind: 'expense',
    ),
    TxCategory(
      id: 'subscriptions',
      name: 'Subscriptions',
      icon: Icons.subscriptions,
      color: Color(0xFF8B5CF6),
      kind: 'expense',
    ),
    TxCategory(
      id: 'other_expense',
      name: 'Other',
      icon: Icons.more_horiz,
      color: Color(0xFF6B7280),
      kind: 'expense',
    ),
  ];

  static const List<TxCategory> income = [
    TxCategory(
      id: 'business',
      name: 'Business',
      icon: Icons.storefront,
      color: AppColors.primary,
      kind: 'income',
    ),
    TxCategory(
      id: 'bonus',
      name: 'Bonus',
      icon: Icons.celebration,
      color: AppColors.primary,
      kind: 'income',
    ),
    TxCategory(
      id: 'salary',
      name: 'Salary',
      icon: Icons.payments,
      color: AppColors.primary,
      kind: 'income',
    ),
    TxCategory(
      id: 'allowance',
      name: 'Allowance',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF22D3EE),
      kind: 'income',
    ),
    TxCategory(
      id: 'gift',
      name: 'Gift',
      icon: Icons.card_giftcard,
      color: Color(0xFFF472B6),
      kind: 'income',
    ),
    TxCategory(
      id: 'freelance',
      name: 'Freelance',
      icon: Icons.laptop_chromebook,
      color: Color(0xFF34D399),
      kind: 'income',
    ),
    TxCategory(
      id: 'other_income',
      name: 'Other',
      icon: Icons.more_horiz,
      color: Color(0xFF6B7280),
      kind: 'income',
    ),
  ];

  static List<TxCategory> all({required String kind}) =>
      kind == 'income' ? income : expense;

  static TxCategory byId(String id) {
    final list = [...income, ...expense];
    return list.firstWhere((c) => c.id == id, orElse: () => expense.last);
  }
}
