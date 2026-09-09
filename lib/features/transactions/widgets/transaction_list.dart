import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import 'tx_list_tile.dart';

/// Filterable transaction history list.
class TransactionList extends StatefulWidget {
  final List<TxRecord> txs;
  final void Function(TxRecord) onTap;

  const TransactionList({
    super.key,
    required this.txs,
    required this.onTap,
  });

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  TxType? _typeFilter;
  String? _categoryFilter;
  String? _accountFilter;
  final _searchCtrl = TextEditingController();
  String _search = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pickDate(
      initial: _startDate ?? _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      helpText: 'Start date',
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDate(
      initial: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      helpText: 'End date',
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime firstDate,
    required String helpText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: helpText,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surfaceContainer,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.txs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long,
                  size: 56, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text(
                'No transactions yet',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add your first one with Quick Add',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final allAccounts = widget.txs.map((t) => t.account).toSet().toList()
      ..sort();
    final allCategories = widget.txs.map((t) => t.category).toSet().toList()
      ..sort();

    final searchLower = _search.trim().toLowerCase();
    final filtered = widget.txs.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.category != _categoryFilter) {
        return false;
      }
      if (_accountFilter != null && t.account != _accountFilter) {
        return false;
      }
      if (searchLower.isNotEmpty) {
        final notes = (t.notes ?? '').toLowerCase();
        final category = Categories.byId(t.category).name.toLowerCase();
        final account = t.account.toLowerCase();
        if (!notes.contains(searchLower) &&
            !category.contains(searchLower) &&
            !account.contains(searchLower)) {
          return false;
        }
      }
      if (_startDate != null && t.occurredAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null) {
        // End is inclusive: include anything up to end-of-day.
        final endInclusive = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (t.occurredAt.isAfter(endInclusive)) return false;
      }
      return true;
    }).toList();

    // Group by financial day
    final groups = <String, List<TxRecord>>{};
    final groupOrder = <String>[];
    for (final t in filtered) {
      final key = D.fullDate(t.occurredAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        groupOrder.add(key);
      }
      groups[key]!.add(t);
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search notes, categories, accounts…',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.onSurfaceVariant, size: 18),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.onSurfaceVariant, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        // Date range row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _DateRangeChip(
                  icon: Icons.event_outlined,
                  label: _startDate == null
                      ? 'Start'
                      : D.shortDate(_startDate!),
                  active: _startDate != null,
                  onTap: _pickStart,
                  onClear: _startDate == null
                      ? null
                      : () => setState(() => _startDate = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateRangeChip(
                  icon: Icons.event_outlined,
                  label: _endDate == null ? 'End' : D.shortDate(_endDate!),
                  active: _endDate != null,
                  onTap: _pickEnd,
                  onClear: _endDate == null
                      ? null
                      : () => setState(() => _endDate = null),
                ),
              ),
            ],
          ),
        ),
        // Filter row
        SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: _typeFilter == null
                    ? 'All Types'
                    : _typeFilter == TxType.income
                        ? 'Income'
                        : 'Expense',
                icon: Icons.swap_vert,
                active: _typeFilter != null,
                onTap: () async {
                  final v = await _pickType();
                  setState(() => _typeFilter = v);
                },
                onClear: _typeFilter == null
                    ? null
                    : () => setState(() => _typeFilter = null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _categoryFilter == null
                    ? 'All Categories'
                    : Categories.byId(_categoryFilter!).name,
                icon: Icons.category_outlined,
                active: _categoryFilter != null,
                onTap: () async {
                  final v = await _pickCategory(allCategories);
                  setState(() => _categoryFilter = v);
                },
                onClear: _categoryFilter == null
                    ? null
                    : () => setState(() => _categoryFilter = null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _accountFilter ?? 'All Accounts',
                icon: Icons.account_balance_wallet_outlined,
                active: _accountFilter != null,
                onTap: () async {
                  final v = await _pickAccount(allAccounts);
                  setState(() => _accountFilter = v);
                },
                onClear: _accountFilter == null
                    ? null
                    : () => setState(() => _accountFilter = null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No transactions match your filters',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: groupOrder.length,
                  itemBuilder: (context, i) {
                    final key = groupOrder[i];
                    final list = groups[key]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(
                            key,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        for (final tx in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TxListTile(
                              tx: tx,
                              onTap: () => widget.onTap(tx),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<TxType?> _pickType() async {
    return showModalBottomSheet<TxType>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filter by Type',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('All'),
              onTap: () => Navigator.pop(context, null),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: AppColors.primary),
              title: const Text('Income'),
              onTap: () => Navigator.pop(context, TxType.income),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: AppColors.error),
              title: const Text('Expense'),
              onTap: () => Navigator.pop(context, TxType.expense),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickCategory(List<String> ids) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filter by Category',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('All'),
              onTap: () => Navigator.pop(context, null),
            ),
            for (final id in ids)
              ListTile(
                leading: Icon(Categories.byId(id).icon,
                    color: Categories.byId(id).color),
                title: Text(Categories.byId(id).name),
                onTap: () => Navigator.pop(context, id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAccount(List<String> names) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filter by Account',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('All'),
              onTap: () => Navigator.pop(context, null),
            ),
            for (final n in names)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(n),
                onTap: () => Navigator.pop(context, n),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: active
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? AppColors.primary
                      : AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close,
                      size: 14, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRangeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      active ? AppColors.primary : AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 14, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}
