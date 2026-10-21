import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../orders/data/models/order.dart';
import '../../../orders/providers/partner_orders_provider.dart';
import '../../data/shop_status_repository.dart';

// The dashboard tab's logic. The incoming-order alarm (dialogs, sound,
// re-fetch on resume) is not here: it stays in HomeScreen, unchanged.

// ── Shop open / closed ───────────────────────────────────────────────────────

/// Tracks shop open/closed state, synced to the vendors table. Null until
/// read. Lives as long as the app, like the provider it replaces.
final shopOpenControllerProvider =
    NotifierProvider<ShopOpenController, bool?>(ShopOpenController.new);

class ShopOpenController extends Notifier<bool?> {
  bool _disposed = false;

  @override
  bool? build() {
    ref.onDispose(() => _disposed = true);
    _init();
    return null;
  }

  Future<void> _init() async {
    final profile = await ref.read(partnerProfileProvider.future);
    if (profile == null) return;
    try {
      final isOpen =
          await ref.read(shopStatusRepositoryProvider).fetchIsOpen(profile.entityId);
      if (!_disposed) state = isOpen ?? true;
    } catch (_) {}
  }

  Future<void> toggle(String entityId, String partnerType) async {
    final next = !(state ?? true);
    state = next;
    await ref.read(shopStatusRepositoryProvider).setIsOpen(entityId, next);
  }
}

// ── Operating-hours schedule ─────────────────────────────────────────────────

@immutable
class ScheduleSettings {
  final bool autoCloseEnabled;
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;

  const ScheduleSettings({
    this.autoCloseEnabled = false,
    this.openingTime,
    this.closingTime,
  });

  ScheduleSettings withAutoClose(bool v) =>
      ScheduleSettings(autoCloseEnabled: v, openingTime: openingTime, closingTime: closingTime);
  ScheduleSettings withOpeningTime(TimeOfDay? v) =>
      ScheduleSettings(autoCloseEnabled: autoCloseEnabled, openingTime: v, closingTime: closingTime);
  ScheduleSettings withClosingTime(TimeOfDay? v) =>
      ScheduleSettings(autoCloseEnabled: autoCloseEnabled, openingTime: openingTime, closingTime: v);
}

/// The shop's default hours. Lives as long as the app, like the provider it
/// replaces.
final scheduleControllerProvider =
    NotifierProvider<ScheduleController, ScheduleSettings>(ScheduleController.new);

class ScheduleController extends Notifier<ScheduleSettings> {
  bool _disposed = false;

  @override
  ScheduleSettings build() {
    ref.onDispose(() => _disposed = true);
    _init();
    return const ScheduleSettings();
  }

  Future<void> _init() async {
    final profile = await ref.read(partnerProfileProvider.future);
    if (profile == null || _disposed) return;
    try {
      final row =
          await ref.read(shopStatusRepositoryProvider).fetchSchedule(profile.entityId);
      if (_disposed) return;
      state = ScheduleSettings(
        autoCloseEnabled: row['auto_close_enabled'] as bool? ?? false,
        openingTime: _parseTime(row['opening_time'] as String?),
        closingTime: _parseTime(row['closing_time'] as String?),
      );
    } catch (_) {}
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save(String entityId, String partnerType) async {
    await ref.read(shopStatusRepositoryProvider).saveSchedule(
          entityId,
          autoCloseEnabled: state.autoCloseEnabled,
          openingTime: state.openingTime != null ? _formatTime(state.openingTime!) : null,
          closingTime: state.closingTime != null ? _formatTime(state.closingTime!) : null,
        );
  }

  Future<void> setAutoClose(bool value, String entityId, String partnerType) async {
    state = state.withAutoClose(value);
    await _save(entityId, partnerType);
  }

  Future<void> setOpeningTime(TimeOfDay time, String entityId, String partnerType) async {
    state = state.withOpeningTime(time);
    await _save(entityId, partnerType);
  }

  Future<void> setClosingTime(TimeOfDay time, String entityId, String partnerType) async {
    state = state.withClosingTime(time);
    await _save(entityId, partnerType);
  }
}

// ── Commission rate ──────────────────────────────────────────────────────────

/// Live platform commission rate taken from the restaurant's subtotal, read
/// from global_settings so the card can never disagree with what the
/// settlement trigger actually deducts. Falls back to the trigger's own
/// default (0.10) when the row is missing.
final commissionRateProvider = FutureProvider.autoDispose<double>((ref) async {
  try {
    final raw =
        await ref.read(shopStatusRepositoryProvider).fetchDefaultCommissionRate();
    return double.tryParse('$raw') ?? 0.10;
  } catch (_) {
    return 0.10;
  }
});

// ── Dashboard orders ─────────────────────────────────────────────────────────

/// The dashboard's order actions. Kept alive by the dashboard tab watching
/// it; while it lives, today's figures are re-read whenever an order
/// changes.
final dashboardControllerProvider =
    NotifierProvider.autoDispose<DashboardController, void>(DashboardController.new);

class DashboardController extends AutoDisposeNotifier<void> {
  @override
  void build() {
    // Today's order count and revenue were read once, like the balance: a
    // delivered order did not move them until the app was reopened. Re-read
    // whenever an order changes (invalidate keeps the old numbers on screen
    // while the new ones load, so nothing flickers).
    ref.listen(partnerOrdersStreamProvider, (_, __) {
      ref.invalidate(dashboardStatsProvider);
    });
  }

  /// Refuses a pending order. Throws when the update is refused.
  Future<bool> reject(String orderId) =>
      ref.read(partnerOrderRepositoryProvider).updateOrderStatus(orderId, OrderStatus.cancelled);

  /// Moves an accepted order on. Throws when the update is refused.
  Future<bool> advance(String orderId, OrderStatus next) =>
      ref.read(partnerOrderRepositoryProvider).updateOrderStatus(orderId, next);

  /// Re-fetch immediately rather than waiting for the realtime channel to
  /// push the new row.
  void refreshOrders() => ref.invalidate(partnerOrdersStreamProvider);

  /// The orders still in the shop's hands or on their way (not delivered,
  /// not cancelled).
  static List<Order> activeOrders(List<Order> orders) =>
      orders.where((o) => o.status.index < 5).toList();

  /// The single status a partner can advance an active order to from the
  /// dashboard card. Mirrors the chain in partner_orders_screen so the two
  /// screens can never disagree about what comes next. Returns null once the
  /// order leaves the partner's hands (ready → the driver takes over) or is
  /// already finished.
  static OrderStatus? nextStatus(OrderStatus current) {
    switch (current) {
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      default:
        return null;
    }
  }
}
