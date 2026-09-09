import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Transaction type: income or expense.
enum TxType {
  income,
  expense;

  String get id => name;

  static TxType fromId(String id) =>
      TxType.values.firstWhere((e) => e.id == id, orElse: () => TxType.expense);

  String get label => this == TxType.income ? 'Income' : 'Expense';

  Color get color => this == TxType.income ? AppColors.primary : AppColors.error;
}

/// Goal category kind. Drives default icon and color when creating a goal.
enum GoalKind {
  emergency,
  travel,
  gaming,
  education,
  custom;

  String get id => name;

  static GoalKind fromId(String id) => GoalKind.values.firstWhere(
        (e) => e.id == id,
        orElse: () => GoalKind.custom,
      );

  String get label => switch (this) {
        GoalKind.emergency => 'Emergency Fund',
        GoalKind.travel => 'Travel',
        GoalKind.gaming => 'Gaming Setup',
        GoalKind.education => 'Education',
        GoalKind.custom => 'Custom',
      };

  IconData get icon => switch (this) {
        GoalKind.emergency => Icons.shield,
        GoalKind.travel => Icons.flight,
        GoalKind.gaming => Icons.sports_esports,
        GoalKind.education => Icons.school,
        GoalKind.custom => Icons.flag,
      };

  Color get color => switch (this) {
        GoalKind.emergency => AppColors.primary,
        GoalKind.travel => Color(0xFF3B82F6),
        GoalKind.gaming => Color(0xFFA855F7),
        GoalKind.education => Color(0xFFEAB308),
        GoalKind.custom => Color(0xFFF97316),
      };
}

enum GoalStatus {
  active,
  completed,
  archived;

  String get id => name;

  static GoalStatus fromId(String id) => GoalStatus.values.firstWhere(
        (e) => e.id == id,
        orElse: () => GoalStatus.active,
      );
}

enum StreakKind {
  saving,
  logging,
  goal;

  String get id => name;

  static StreakKind fromId(String id) => StreakKind.values.firstWhere(
        (e) => e.id == id,
        orElse: () => StreakKind.saving,
      );

  String get label => switch (this) {
        StreakKind.saving => 'Saving Streak',
        StreakKind.logging => 'Logging Streak',
        StreakKind.goal => 'Goal Streak',
      };
}

/// Account category. Drives the icon, color, and the Home grouping
/// (Cash / Banks / E-wallets / Savings / Digital / Other). The id matches
/// the values stored in `accounts.type` (text column) so existing rows
/// seed cleanly without a migration.
enum AccountType {
  cash,
  bank,
  ewallet,
  savings,
  digital,
  other;

  String get id => switch (this) {
        // Aliases kept for backwards compatibility with the original seed
        // values ("cash" / "bank" / "ewallet").
        AccountType.cash => 'cash',
        AccountType.bank => 'bank',
        AccountType.ewallet => 'ewallet',
        AccountType.savings => 'savings',
        AccountType.digital => 'digital',
        AccountType.other => 'other',
      };

  static AccountType fromId(String? id) {
    switch (id) {
      case 'cash':
        return AccountType.cash;
      case 'bank':
        return AccountType.bank;
      case 'ewallet':
      case 'gcash':
      case 'maya':
      case 'gotyme':
        return AccountType.ewallet;
      case 'savings':
        return AccountType.savings;
      case 'digital':
      case 'crypto':
        return AccountType.digital;
      default:
        return AccountType.other;
    }
  }

  String get label => switch (this) {
        AccountType.cash => 'Cash',
        AccountType.bank => 'Bank',
        AccountType.ewallet => 'E-Wallet',
        AccountType.savings => 'Savings',
        AccountType.digital => 'Digital',
        AccountType.other => 'Other',
      };

  IconData get icon => switch (this) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.ewallet => Icons.account_balance_wallet_outlined,
        AccountType.savings => Icons.savings_outlined,
        AccountType.digital => Icons.currency_bitcoin,
        AccountType.other => Icons.wallet_outlined,
      };

  Color get color => switch (this) {
        AccountType.cash => const Color(0xFF22C55E),
        AccountType.bank => const Color(0xFF3B82F6),
        AccountType.ewallet => const Color(0xFFA855F7),
        AccountType.savings => const Color(0xFF14B8A6),
        AccountType.digital => const Color(0xFFEAB308),
        AccountType.other => const Color(0xFF6B7280),
      };
}