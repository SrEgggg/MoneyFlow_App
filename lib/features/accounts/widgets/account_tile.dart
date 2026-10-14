import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Single row representing an account. Used on both the Accounts screen and
/// the Home accounts overview.
class AccountTile extends StatelessWidget {
  final AccountRecord account;
  final VoidCallback? onTap;

  const AccountTile({super.key, required this.account, this.onTap});

  Color _hexColor() {
    final raw = account.color.replaceAll('#', '');
    final v = int.tryParse('FF$raw', radix: 16);
    return v == null ? AccountType.fromId(account.type).color : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final type = AccountType.fromId(account.type);
    final color = _hexColor();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(type.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (account.name.toLowerCase() != type.label.toLowerCase())
                    Text(
                      type.label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Money.of(context).format(account.balance),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
