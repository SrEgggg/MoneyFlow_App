import '../../core/widgets/startup_state.dart';
import '../../core/widgets/app_ui.dart';
import '../transactions/widgets/category_management_screen.dart';
import '../../data/services/backup_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/models.dart';
import '../../data/seed/seed_data.dart';
import '../../providers.dart';
import '../home/providers/home_providers.dart';

/// Settings tab. Profile, financial day cutoff, currency, clear data, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _themeBusy = false;
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileSection(settings: settings),
            const SizedBox(height: 24),
            SectionCard(
              framed: false,
              title: 'Appearance',
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    ['light', 'dark', 'system'].contains(settings.themeMode)
                    ? settings.themeMode
                    : 'system',
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('System default'),
                  ),
                  DropdownMenuItem(value: 'light', child: Text('Light mode')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark mode')),
                ],
                onChanged: _themeBusy
                    ? null
                    : (value) async {
                        if (value == null) return;
                        setState(() => _themeBusy = true);
                        try {
                          await ref
                              .read(settingsProvider.notifier)
                              .save(settings.copyWith(themeMode: value));
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save appearance. Please try again.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _themeBusy = false);
                        }
                      },
              ),
            ),

            const SizedBox(height: 12),
            _PreferencesSection(settings: settings),
            const SizedBox(height: 12),
            const _PlanningSection(),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Custom categories'),
              subtitle: const Text('Edit names, icons and colors'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _BackupSection(),
            const SizedBox(height: 12),
            const _DataSection(),
            const SizedBox(height: 12),
            const _AboutSection(),
            const SizedBox(height: 24),
          ],
        ),
        loading: () => const LoadingPlaceholder(lines: 4),
        error: (_, __) => InlineNotice(
          message:
              'Could not load settings. Your saved data has not been changed.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(settingsProvider),
        ),
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  final SettingsRecord settings;
  const _ProfileSection({required this.settings});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Profile',
      child: Column(
        children: [
          AsyncAction(
            action: () => _editName(context, ref),
            builder: (busy, run) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              title: Text(
                settings.displayName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Display name',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              onTap: busy ? null : run,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: settings.displayName);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: const Text('Display name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Your name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Display name is required'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (result != null && result.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Display name is required')),
        );
      return;
    }
    if (result != null) {
      try {
        await ref
            .read(settingsProvider.notifier)
            .save(settings.copyWith(displayName: result));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save your name. Reopen Profile and try again.',
              ),
            ),
          );
        }
      }
    }
  }
}

class _PreferencesSection extends ConsumerWidget {
  final SettingsRecord settings;
  const _PreferencesSection({required this.settings});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Preferences',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              'Financial day cutoff',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${settings.cutoffHour.toString().padLeft(2, '0')}:00 — transactions before this belong to the previous day',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: DropdownButton<int>(
              value: settings.cutoffHour,
              dropdownColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              underline: const SizedBox.shrink(),
              items: [
                for (int h = 0; h < 6; h++)
                  DropdownMenuItem(
                    value: h,
                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                  ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await ref
                    .read(settingsProvider.notifier)
                    .save(settings.copyWith(cutoffHour: v));
              },
            ),
          ),
          Divider(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            height: 24,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.attach_money,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              'Currency',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${settings.currency} · Display only; amounts are not converted',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: DropdownButton<String>(
              value: settings.currency,
              dropdownColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'PHP', child: Text('PHP ₱')),
                DropdownMenuItem(value: 'USD', child: Text('USD \$')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await ref
                    .read(settingsProvider.notifier)
                    .save(settings.copyWith(currency: v));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningSection extends StatelessWidget {
  const _PlanningSection();
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Planning',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.pie_chart_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              'Budgets',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Monthly spending limits by category',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onTap: () => context.push(Routes.budgets),
          ),
          Divider(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            height: 24,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.autorenew_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            title: Text(
              'Recurring transactions',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Salary, rent, subscriptions — rules that auto-post on a schedule and can be run on demand.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onTap: () => context.push(Routes.recurring),
          ),
        ],
      ),
    );
  }
}

class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();
  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;
  Future<void> _run(bool restore) async {
    if (_busy) return;
    setState(() => _busy = true);
    var committed = false;
    try {
      final service = ref.read(backupServiceProvider);
      final files = ref.read(backupFilesProvider);
      if (!restore) {
        final saved = await files.save(await service.exportJsonString());
        if (saved && mounted) {
          _message('Backup saved. Keep it somewhere private.');
        }
        return;
      }
      final selected = await files.pick();
      if (selected == null || !mounted) return;
      final summary = await service.inspectJson(selected.json);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Replace data with this backup?'),
          content: SingleChildScrollView(
            child: Text(
              '${selected.name}\n\nExported: ${summary.exportedAt?.toLocal().toString() ?? 'Unknown date'}\n'
              '${summary.tableCounts['accounts'] ?? 0} accounts · ${summary.tableCounts['transactions'] ?? 0} transactions · ${summary.tableCounts['goals'] ?? 0} goals\n\n'
              'This replaces your current data and preferences. Export a backup first if you want to keep them.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Replace data'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await service.restoreFromJsonString(selected.json);
      committed = true;
      ref.invalidate(settingsProvider);
      ref.invalidate(customCategoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(journalProvider);
      ref.invalidate(streaksProvider);
      ref.invalidate(earnedAchievementsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(recurringProvider);
      ref.invalidate(homeSummaryProvider);
      await ref.read(refreshDerivedDataProvider)();
      if (mounted) _message('Backup restored. Your saved data is ready.');
    } catch (error) {
      if (mounted) {
        _message(
          committed
              ? 'Backup restored. Refresh Home to reload totals.'
              : restore
              ? 'Could not restore this backup. Your data is unchanged. ${error is FormatException ? error.message : 'Choose another file and try again.'}'
              : 'Could not export your backup. Your data is unchanged. Try another location.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Backup',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Save a portable copy of your data, or restore a backup you choose.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(false),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(true),
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 8),
        Text(
          'Backup files include financial history, notes and goal photos. They are not password protected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _DataSection extends ConsumerWidget {
  const _DataSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      framed: false,
      title: 'Data',
      child: Column(
        children: [
          if (kDebugMode) ...[
            AsyncAction(
              action: () => _confirmReseed(context, ref),
              builder: (busy, run) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.restart_alt,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Reset to demo data',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Wipes all your data and loads the bundled demo (Kyle, 3 accounts, 3 goals, 30 days of activity). Useful for previews or after a real-data test.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                onTap: busy ? null : run,
              ),
            ),
            Divider(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              height: 24,
            ),
          ],
          AsyncAction(
            action: () => _confirmClear(context, ref),
            builder: (busy, run) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
              ),
              title: Text(
                'Clear all data',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Removes all accounts, transactions, goals, journal entries, streaks, and preferences. The app returns to its first-install state.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              onTap: busy ? null : run,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every account, transaction, goal, '
          'journal entry, streak, and preference on this device. '
          'After clearing, the app will look exactly like a brand-new '
          'install with no data. Previously exported backup files are kept; delete those separately if needed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Wipe every user-data table, then re-run the first-run initializer
    // (which only inserts the default empty settings row).
    final db = await ref.read(databaseProvider.future);
    try {
      await db.wipe();
      await FirstRunInitializer(db).ensureInitialized();
      // Close the cached DB handle so providers re-open against the wiped
      // database and observers see a fresh, empty state.
      // Force every cached provider to rebuild from the empty DB.
      ref.invalidate(dailyCacheForMonthProvider);
      ref.invalidate(dailyCacheForDayProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(customCategoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(journalProvider);
      ref.invalidate(streaksProvider);
      ref.invalidate(earnedAchievementsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(recurringProvider);
      ref.invalidate(homeSummaryProvider);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All data cleared. Welcome back to a fresh start.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Clear failed: $e')));
      }
    }
  }

  Future<void> _confirmReseed(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        icon: Icon(
          Icons.restart_alt,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        title: const Text('Reset to demo data?'),
        content: const Text(
          'This wipes everything on this device and replaces it with the '
          'bundled demo (Kyle, 3 accounts, 3 goals, 30 days of activity). '
          'Use this for previews or after a real-data test. Your current '
          'data will be lost unless you exported a backup first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final db = await ref.read(databaseProvider.future);
    try {
      await SeedRunner(db).reseed();
      ref.invalidate(dailyCacheForMonthProvider);
      ref.invalidate(dailyCacheForDayProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(customCategoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(journalProvider);
      ref.invalidate(streaksProvider);
      ref.invalidate(earnedAchievementsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(recurringProvider);
      ref.invalidate(homeSummaryProvider);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demo data loaded. Welcome back, Kyle.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Reset failed: $e')));
      }
    }
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      framed: false,
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 56),
          const SizedBox(height: 12),
          Text(
            'MoneyFlow v4.0',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'A personal savings tracker. No app-managed cloud sync. Data is stored locally; backups leave the app only when you export them. Device transfer behavior may depend on your operating system.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
