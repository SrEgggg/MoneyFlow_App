import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/categories.dart';
import '../../../providers.dart';

/// Shared picker for new entries and edits. Saved categories remain reusable
/// even if the surrounding transaction form is subsequently cancelled.
class CategoryPicker extends StatelessWidget {
  final String kind;
  final String? selected;
  final ValueChanged<String> onChanged;
  const CategoryPicker({
    super.key,
    required this.kind,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = Categories.available(context, kind, selected: selected);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ChoiceChip(
            side: BorderSide(
              color: selected == c.id
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: selected == c.id ? 1.5 : 1,
            ),
            avatar: Icon(
              c.icon,
              color: selected == c.id
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            label: Text(c.name),
            selected: selected == c.id,
            onSelected: (_) => onChanged(c.id),
            tooltip: c.name,
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Other / Custom category'),
          onPressed: () async {
            final created = await showDialog<TxCategory>(
              context: context,
              builder: (_) => CategoryEditorDialog(kind: kind),
            );
            if (created != null && context.mounted) onChanged(created.id);
          },
        ),
      ],
    );
  }
}

class CategoryEditorDialog extends ConsumerStatefulWidget {
  final String kind;
  final TxCategory? existing;
  const CategoryEditorDialog({super.key, required this.kind, this.existing});
  @override
  ConsumerState<CategoryEditorDialog> createState() =>
      CategoryEditorDialogState();
}

class CategoryEditorDialogState extends ConsumerState<CategoryEditorDialog> {
  final _name = TextEditingController();
  String _icon = 'label';
  Color _color = customCategoryColors.first;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final category = widget.existing;
    if (category != null) {
      _name.text = category.name;
      _color = category.color;
      _icon = customCategoryIcons.entries
          .firstWhere(
            (e) => e.value == category.icon,
            orElse: () => customCategoryIcons.entries.first,
          )
          .key;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = await ref
          .read(categoryRepoProvider)
          .create(
            _name.text,
            widget.kind,
            iconKey: _icon,
            color: _color,
            existingId: widget.existing?.id,
          );
      ref.invalidate(customCategoriesProvider);
      await ref.read(customCategoriesProvider.future);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, category);
      messenger.showSnackBar(
        const SnackBar(content: Text('Category saved for future transactions')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is FormatException
            ? e.message
            : 'Could not save category. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.existing == null ? 'Custom category' : 'Edit category',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved to your ${widget.kind} categories.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Pet care',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            const Text('Icon'),
            Wrap(
              spacing: 4,
              children: [
                for (final entry in customCategoryIcons.entries)
                  IconButton(
                    tooltip: entry.key,
                    isSelected: _icon == entry.key,
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == entry.key
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _icon = entry.key),
                    icon: Icon(entry.value, color: _color),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Color'),
            Wrap(
              spacing: 4,
              children: [
                for (var i = 0; i < customCategoryColors.length; i++)
                  IconButton(
                    tooltip: [
                      'Blue',
                      'Green',
                      'Purple',
                      'Rose',
                      'Amber',
                      'Teal',
                    ][i],
                    isSelected: _color == customCategoryColors[i],
                    onPressed: _saving
                        ? null
                        : () =>
                              setState(() => _color = customCategoryColors[i]),
                    icon: Icon(
                      _color == customCategoryColors[i]
                          ? Icons.check_circle
                          : Icons.circle,
                      color: customCategoryColors[i],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save category'),
        ),
      ],
    ),
  );
}
