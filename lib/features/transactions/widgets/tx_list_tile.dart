import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

class TxListTile extends StatelessWidget {
  final TxRecord tx;
  final VoidCallback onTap;
  const TxListTile({super.key, required this.tx, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final category = Categories.resolve(context, tx.category);
    final transfer = tx.type == TxType.transfer;
    final income = tx.type == TxType.income;
    final color = transfer
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF60A5FA)
              : const Color(0xFF2563EB))
        : income
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final amount =
        '${transfer
            ? '↔ '
            : income
            ? '+'
            : '-'}${Money.of(context).format(tx.amount)}';
    final title = transfer ? 'Transfer' : category.name;
    final description = transfer
        ? '${tx.account} → ${tx.destinationAccount}'
        : '${tx.account} · ${D.dayMonth(tx.occurredAt)}';
    return Semantics(
      button: true,
      label:
          '${tx.type.label}, $title, ${Money.of(context).format(tx.amount)}, $description',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final amountText = Text(
                  amount,
                  textAlign: stacked ? TextAlign.start : TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        transfer ? Icons.swap_vert : category.icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (stacked) ...[
                            const SizedBox(height: AppSpace.xs),
                            amountText,
                          ],
                        ],
                      ),
                    ),
                    if (!stacked) ...[
                      const SizedBox(width: AppSpace.sm),
                      Flexible(fit: FlexFit.tight, child: amountText),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
