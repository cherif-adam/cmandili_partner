import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/reports_repository.dart';

final reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) => ReportsRepository());

/// The figures for one period ('today', 'week' or 'month'). Kept alive like
/// before, so coming back to a period shows it at once.
final reportsStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final profile = await ref.watch(partnerProfileProvider.future);
  if (profile == null) return _emptyStats();

  // Generic vendors ride restaurant_id like restaurants do; only supermarkets
  // use supermarket_id. See partner_order_repository.getPartnerOrders.
  final filterColumn =
      profile.partnerType == 'supermarket' ? 'supermarket_id' : 'restaurant_id';

  final now = DateTime.now();
  DateTime start;
  if (period == 'today') {
    start = DateTime(now.year, now.month, now.day);
  } else if (period == 'week') {
    start = now.subtract(Duration(days: now.weekday - 1));
    start = DateTime(start.year, start.month, start.day);
  } else {
    start = DateTime(now.year, now.month, 1);
  }

  try {
    final all = await ref.read(reportsRepositoryProvider).ordersSince(
          filterColumn: filterColumn,
          entityId: profile.entityId,
          start: start,
        );
    final delivered = all.where((r) => r['status'] == 'delivered').toList();
    final cancelled = all.where((r) => r['status'] == 'cancelled').toList();

    final totalRevenue = delivered.fold<double>(0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
    final totalFees = delivered.fold<double>(0, (s, r) => s + ((r['delivery_fee'] as num?)?.toDouble() ?? 0));

    return {
      'totalOrders': all.length,
      'deliveredOrders': delivered.length,
      'cancelledOrders': cancelled.length,
      'totalRevenue': totalRevenue,
      'deliveryFees': totalFees,
    };
  } catch (e, st) {
    return Error.throwWithStackTrace(
      Exception('Failed to load reports: $e'),
      st,
    );
  }
});

Map<String, dynamic> _emptyStats() => {
  'totalOrders': 0,
  'deliveredOrders': 0,
  'cancelledOrders': 0,
  'totalRevenue': 0.0,
  'deliveryFees': 0.0,
};

/// One controller per reports screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is the chosen period.
final reportsControllerProvider = NotifierProvider.autoDispose
    .family<ReportsController, String, Object>(ReportsController.new);

class ReportsController extends AutoDisposeFamilyNotifier<String, Object> {
  @override
  String build(Object screenKey) => 'today';

  // ── User actions ──────────────────────────────────────────────────────────

  void selectPeriod(String period) => state = period;

  /// Loads the current period again after an error.
  void retry() => ref.invalidate(reportsStatsProvider(state));
}
