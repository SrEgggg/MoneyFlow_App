import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';
import '../providers/home_providers.dart';

/// The hero card on Home. Renders the total savings number, the percentage
/// change vs last month, the count of accounts, a stylized sparkline
/// illustration of the savings trend, and a horizontal row of per-type
/// account summary chips (Bank / E-Wallet / Cash / + Add Account).
class TotalSavingsCard extends ConsumerWidget {
  const TotalSavingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return summaryAsync.when(
      loading: () => const _LoadingHero(),
      error: (e, _) => _ErrorHero(message: '$e'),
      data: (s) {
        final accounts = accountsAsync.maybeWhen(
          data: (v) => v,
          orElse: () => const <AccountRecord>[],
        );
        return _Hero(
          total: s.totalSavings,
          deltaPercent: s.netWorthChangePercent,
          accounts: accounts,
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  final double total;
  final double deltaPercent;
  final List<AccountRecord> accounts;
  const _Hero({
    required this.total,
    required this.deltaPercent,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    final positive = deltaPercent >= 0;
    final hasAccounts = accounts.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF16A34A),
            Color(0xFF15803D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SparklinePainter(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Savings',
                        style: TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    _ManagePill(
                      label: hasAccounts ? 'Manage' : '+ Add account',
                      onTap: () => context.go(Routes.accounts),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            positive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${deltaPercent.abs().toStringAsFixed(1)}% vs last month',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasAccounts
                          ? 'Across ${accounts.length} ${accounts.length == 1 ? "account" : "accounts"}'
                          : 'Add your first account',
                      style: const TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (hasAccounts) ...[
                  const SizedBox(height: 18),
                  _TypeBreakdownRow(accounts: accounts),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ManagePill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBreakdownRow extends StatelessWidget {
  final List<AccountRecord> accounts;
  const _TypeBreakdownRow({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final totals = <AccountType, double>{};
    for (final a in accounts) {
      final t = AccountType.fromId(a.type);
      totals[t] = (totals[t] ?? 0) + a.balance;
    }
    final entries = totals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = entries.take(3).toList();

    return Row(
      children: [
        for (int i = 0; i < top3.length; i++) ...[
          Expanded(
            child: _TypeChip(type: top3[i].key, total: top3[i].value),
          ),
          if (i < top3.length - 1) const SizedBox(width: 8),
        ],
        if (top3.length < 3) ...[
          for (int i = top3.length; i < 3; i++) ...[
            const SizedBox(width: 8),
            Expanded(child: _AddAccountChip(onTap: () => context.go(Routes.accounts))),
          ],
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final AccountType type;
  final double total;
  const _TypeChip({required this.type, required this.total});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(Routes.accounts),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(type.icon, color: Colors.white, size: 13),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                Money.compact(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAccountChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAccountChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              style: BorderStyle.solid,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple decorative savings-trend sparkline drawn into the hero card.
/// Uses deterministic-but-pleasing curves so the empty state still looks
/// finished even before the user logs any transactions.
class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final n = 24;
    final points = <Offset>[];
    final baseY = size.height * 0.78;
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final x = t * size.width;
      final y = baseY - (t * size.height * 0.45) + (rng.nextDouble() - 0.5) * 18;
      points.add(Offset(x, y));
    }
    // Build a smooth path using mid-point quadratic curves.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[i - 1];
      final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    // Underline-area gradient.
    final fill = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[i - 1];
      final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
      fill.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    fill.lineTo(points.last.dx, points.last.dy);
    fill.lineTo(points.last.dx, size.height);
    fill.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.32),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    // Line.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Endpoint dot.
    canvas.drawCircle(points.last, 4, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 4,
        Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.color != color;
}

class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    );
  }
}

class _ErrorHero extends StatelessWidget {
  final String message;
  const _ErrorHero({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Total savings unavailable: $message',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}