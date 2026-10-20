import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'reports_controller.dart';

/// "Rapports", top to bottom:
///   _PeriodSelector   today / this week / this month
///   _ReportBody       spinner, error with retry, or the figures:
///                     _RevenueCard, _StatsGrid
///
/// UI only: the period lives in [ReportsController], the figures in
/// [reportsStatsProvider].
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  /// This screen's own controller (see [reportsControllerProvider]).
  late final _provider = reportsControllerProvider(Object());

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final statsAsync = ref.watch(reportsStatsProvider(period));
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.reportsAnalytics, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PeriodSelector(selected: period, onSelected: controller.selectPeriod),
          const SizedBox(height: 20),
          _ReportBody(stats: statsAsync, onRetry: controller.retry),
        ],
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _PeriodTab(label: l.today, value: 'today', selected: selected, onTap: onSelected),
          _PeriodTab(label: l.thisWeek, value: 'week', selected: selected, onTap: onSelected),
          _PeriodTab(label: l.thisMonth, value: 'month', selected: selected, onTap: onSelected),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.stats, required this.onRetry});

  final AsyncValue<Map<String, dynamic>> stats;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return stats.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(l.couldNotLoadReports, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      ),
      data: (stats) => Column(
        children: [
          _RevenueCard(stats: stats),
          const SizedBox(height: 16),
          _StatsGrid(stats: stats),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.totalRevenue, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${(stats['totalRevenue'] as double).toStringAsFixed(2)} DT',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Delivery fees: ${(stats['deliveryFees'] as double).toStringAsFixed(2)} DT',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: l.totalOrders, value: '${stats['totalOrders']}', icon: Icons.receipt_long_rounded, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: l.delivered, value: '${stats['deliveredOrders']}', icon: Icons.check_circle_rounded, color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: l.cancelled, value: '${stats['cancelledOrders']}', icon: Icons.cancel_rounded, color: AppColors.error)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: l.successRate,
              value: stats['totalOrders'] > 0
                  ? '${((stats['deliveredOrders'] / stats['totalOrders']) * 100).toStringAsFixed(0)}%'
                  : '—',
              icon: Icons.trending_up_rounded,
              color: AppColors.secondary,
            )),
          ],
        ),
      ],
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _PeriodTab({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
