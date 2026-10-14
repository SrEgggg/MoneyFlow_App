import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/constants/categories.dart';
import '../../../providers.dart';
import 'category_picker.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Custom categories')),
    body: ref
        .watch(customCategoriesProvider)
        .when(
          loading: () => const LoadingPlaceholder(),
          error: (_, __) => InlineNotice(
            message: 'Could not load categories.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(customCategoriesProvider),
          ),
          data: (catalog) {
            final categories = catalog.where((c) => !c.archived).toList();
            if (categories.isEmpty) {
              return const Padding(
                padding: AppSpace.page,
                child: InlineNotice(
                  message:
                      'No custom categories yet. Create one when adding a transaction.',
                ),
              );
            }
            return ListView.builder(
              padding: AppSpace.page,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(category.icon, color: category.color),
                  title: Text(category.name),
                  subtitle: Text(
                    category.kind == 'income' ? 'Income' : 'Expense',
                  ),
                  onTap: () => showDialog<TxCategory>(
                    context: context,
                    builder: (_) => CategoryEditorDialog(
                      kind: category.kind,
                      existing: category,
                    ),
                  ),
                  trailing: AsyncAction(
                    action: () => _delete(context, ref, category),
                    builder: (busy, run) => IconButton(
                      tooltip: 'Delete ${category.name}',
                      onPressed: busy ? null : run,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            );
          },
        ),
  );

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TxCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '${category.name} will no longer appear for new transactions. Existing transactions, budgets and scheduled entries keep their category. No amounts or balances will change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(c).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(categoryRepoProvider).remove(category.id);
      ref.invalidate(customCategoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category removed from new entries')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remove category. Reopen the list and try again.',
            ),
          ),
        );
      }
    }
  }
}
