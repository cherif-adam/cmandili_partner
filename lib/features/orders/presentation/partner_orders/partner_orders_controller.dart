import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../providers/partner_orders_provider.dart';

/// The orders tab's logic. Its state is the status filter (null: all); the
/// orders themselves come from partnerOrdersStreamProvider. Kept alive by
/// the screen watching it.
final partnerOrdersControllerProvider =
    NotifierProvider.autoDispose<PartnerOrdersController, OrderStatus?>(
        PartnerOrdersController.new);

class PartnerOrdersController extends AutoDisposeNotifier<OrderStatus?> {
  @override
  OrderStatus? build() => null;

  // ── User actions ──────────────────────────────────────────────────────────

  void setFilter(OrderStatus? status) => state = status;

  /// Throws when the update is refused.
  Future<bool> updateStatus(String orderId, OrderStatus status) =>
      ref.read(partnerOrderRepositoryProvider).updateOrderStatus(orderId, status);

  // ── Rules ─────────────────────────────────────────────────────────────────

  /// [orders] with the chosen status, or all of them.
  List<Order> filter(List<Order> orders) => state == null
      ? orders
      : orders.where((o) => o.status == state).toList();

  /// "Delivered" only for an order the shop delivers itself: when a driver
  /// carries it, the driver marks it delivered (the database refuses it from
  /// the partner).
  static List<OrderStatus> nextStatuses(OrderStatus current, {bool selfDelivery = false}) {
    switch (current) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready];
      case OrderStatus.ready:
        return [OrderStatus.pickedUp, OrderStatus.onTheWay];
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return selfDelivery ? [OrderStatus.delivered] : [];
      default:
        return [];
    }
  }
}
