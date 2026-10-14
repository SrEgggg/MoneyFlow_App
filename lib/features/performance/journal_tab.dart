import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/moods.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Journal tab: today's mood + entry form, plus recent entries list.
class JournalTab extends ConsumerStatefulWidget {
  const JournalTab({super.key});

  @override
  ConsumerState<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends ConsumerState<JournalTab> {
  String? _mood;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final mood = _mood;
    final content = _contentCtrl.text.trim();
    if (mood == null) {
      _err('Pick a mood');
      return;
    }
    if (content.isEmpty) {
      _err('Write something for today');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await ref
          .read(journalProvider.notifier)
          .add(
            JournalRecord(
              entryDate: DateTime(now.year, now.month, now.day),
              mood: mood,
              title: _titleCtrl.text.trim().isEmpty
                  ? null
                  : _titleCtrl.text.trim(),
              content: content,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _mood = null;
        _titleCtrl.clear();
        _contentCtrl.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Journal entry saved')));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _err('Could not save this entry. Try again.');
      }
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: "Today's Entry",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you feeling about your finances today?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              _MoodSelector(
                value: _mood,
                onSelect: (m) => setState(() => _mood = m),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText:
                      "What happened today? What did you learn? What's the plan?",
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.book_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save Entry'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        entriesAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No journal entries yet',
                subtitle:
                    'Write your first entry above — even one line helps you reflect.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'Recent Entries',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final e in entries) _JournalEntryCard(entry: e),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onSelect;
  const _MoodSelector({required this.value, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in Moods.all)
          InkWell(
            onTap: () => onSelect(m.id),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: value == m.id
                    ? m.color.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value == m.id ? m.color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.icon,
                    size: 16,
                    color: value == m.id
                        ? m.color
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    m.label,
                    style: TextStyle(
                      color: value == m.id
                          ? m.color
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalRecord entry;
  const _JournalEntryCard({required this.entry});
  @override
  Widget build(BuildContext context) {
    final mood = Moods.byId(entry.mood);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mood.icon, color: mood.color, size: 18),
                const SizedBox(width: 8),
                Text(
                  mood.label,
                  style: TextStyle(
                    color: mood.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  D.relativeDay(entry.entryDate),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if ((entry.title ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.title!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              entry.content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
