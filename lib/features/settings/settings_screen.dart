import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/models.dart';
import '../../data/seed/seed_data.dart';
import '../../data/services/backup_service.dart';
import '../../providers.dart';
import '../home/providers/home_providers.dart';

/// Settings tab. Profile, financial day cutoff, currency, clear data, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileSection(settings: settings),
            const SizedBox(height: 12),
            _PreferencesSection(settings: settings),
            const SizedBox(height: 12),
            const _PlanningSection(),
            const SizedBox(height: 12),
            const _BackupSection(),
            const SizedBox(height: 12),
            const _DataSection(),
            const SizedBox(height: 12),
            const _AboutSection(),
            const SizedBox(height: 24),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            title: Text(
              settings.displayName,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Display name',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.edit_outlined,
              color: AppColors.onSurfaceVariant,
              size: 18,
            ),
            onTap: () => _editName(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: settings.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Display name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (result != null && result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name is required')));
      return;
    }
    if (result != null) {
      await ref
          .read(settingsProvider.notifier)
          .save(settings.copyWith(displayName: result));
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
            leading: const Icon(
              Icons.access_time,
              color: AppColors.onSurfaceVariant,
            ),
            title: const Text(
              'Financial day cutoff',
              style: TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
            subtitle: Text(
              '${settings.cutoffHour.toString().padLeft(2, '0')}:00 — transactions before this belong to the previous day',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            trailing: DropdownButton<int>(
              value: settings.cutoffHour,
              dropdownColor: AppColors.surfaceContainerHigh,
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
          const Divider(color: AppColors.surfaceContainerHigh, height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.attach_money,
              color: AppColors.onSurfaceVariant,
            ),
            title: const Text(
              'Currency',
              style: TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
            subtitle: Text(
              settings.currency,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            trailing: DropdownButton<String>(
              value: settings.currency,
              dropdownColor: AppColors.surfaceContainerHigh,
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
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.pie_chart_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: const Text(
              'Budgets',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Set monthly spending caps per category and watch progress against your actual spend.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
            onTap: () => context.push(Routes.budgets),
          ),
          const Divider(color: AppColors.surfaceContainerHigh, height: 24),
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
            title: const Text(
              'Recurring transactions',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Salary, rent, subscriptions — rules that auto-post on a schedule and can be run on demand.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
            onTap: () => context.push(Routes.recurring),
          ),
        ],
      ),
    );
  }
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Export every account, transaction, goal, budget, recurring '
              'rule, and journal entry to a single JSON file you can keep '
              'off-device. Restore on a fresh install from the same file.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _doExport(context, ref),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showRestoreHint(context, ref),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Backups are written to the app documents folder; share them '
              'out using your file manager of choice. Restore reads any '
              'exported MoneyFlow JSON file from that folder.',
              style: TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final svc = ref.read(backupServiceProvider);
    try {
      final file = await svc.exportToFile();
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: file.path));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup saved to ${file.path}. Path copied.'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showRestoreHint(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        title: const Text('Restore from backup?'),
        content: const Text(
          'Restoring will REPLACE every row in your database with the '
          'contents of the most recent backup file in the app documents '
          'folder. Use this after a fresh install or to roll back to a '
          'previous export. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    try {
      final svc = ref.read(backupServiceProvider);
      final reports = await _findLatestBackup(svc);
      if (reports == null) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No backup file found. Export first, then copy the JSON back '
              'into the app documents folder before restoring.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final report = await svc.restoreFromFile(reports);


      ref.invalidate(dailyCacheForMonthProvider);
      ref.invalidate(dailyCacheForDayProvider);
      ref.invalidate(settingsProvider);
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
        SnackBar(
          content: Text(
            'Restored ${report.totalRows} rows across '
            '${report.rowCounts.length} tables.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Pick the newest backup file from the documents directory.
  Future<File?> _findLatestBackup(BackupService svc) async {
    final dir = await getApplicationDocumentsDirectory();
    final entries = dir.listSync().whereType<File>().toList();
    final backups = entries
        .where((f) => p.basename(f.path).startsWith('moneyflow-backup-'))
        .toList();
    if (backups.isEmpty) return null;
    backups.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return backups.first;
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Data',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restart_alt,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: const Text(
              'Reset to demo data',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Wipes all your data and loads the bundled demo (Kyle, 3 accounts, 3 goals, 30 days of activity). Useful for previews or after a real-data test.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            onTap: () => _confirmReseed(context, ref),
          ),
          const Divider(color: AppColors.surfaceContainerHigh, height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.error,
                size: 20,
              ),
            ),
            title: const Text(
              'Clear all data',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Removes all accounts, transactions, goals, journal entries, streaks, and preferences. The app returns to its first-install state.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            onTap: () => _confirmClear(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 32,
        ),
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every account, transaction, goal, '
          'journal entry, streak, and preference on this device. '
          'After clearing, the app will look exactly like a brand-new '
          'install with no data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
    try { await db.wipe();
    await FirstRunInitializer(db).ensureInitialized();

    // Close the cached DB handle so providers re-open against the wiped
    // database and observers see a fresh, empty state.

    // Force every cached provider to rebuild from the empty DB.

    ref.invalidate(dailyCacheForMonthProvider);
    ref.invalidate(dailyCacheForDayProvider);
    ref.invalidate(settingsProvider);
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
    } catch (e) { if (context.mounted) messenger.showSnackBar(SnackBar(content: Text('Clear failed: $e'))); }
  }

  Future<void> _confirmReseed(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        icon: const Icon(Icons.restart_alt, color: AppColors.primary, size: 32),
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
    try { await SeedRunner(db).reseed();

    ref.invalidate(dailyCacheForMonthProvider);
    ref.invalidate(dailyCacheForDayProvider);
    ref.invalidate(settingsProvider);
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
    } catch (e) { if (context.mounted) messenger.showSnackBar(SnackBar(content: Text('Reset failed: $e'))); }
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MoneyFlow v4.0',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Savings & Financial Performance Platform. Local-first. No accounts. No cloud. All your data stays on this device.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
