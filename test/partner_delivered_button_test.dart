import 'dart:io';

import 'package:cmandili_partner/features/orders/data/models/order.dart';
import 'package:cmandili_partner/features/orders/presentation/order_detail/order_detail_controller.dart';
import 'package:cmandili_partner/features/orders/presentation/partner_orders/partner_orders_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Livrée" belongs to whoever carries the order: the partner only for an
/// order the shop delivers itself. The database refuses it otherwise, so the
/// app must not offer the button.
void main() {
  const inTransit = [OrderStatus.pickedUp, OrderStatus.onTheWay];

  test('orders list: no "delivered" for an order a driver carries', () {
    for (final s in inTransit) {
      expect(PartnerOrdersController.nextStatuses(s), isEmpty);
      expect(PartnerOrdersController.nextStatuses(s, selfDelivery: true), [OrderStatus.delivered]);
    }
    expect(PartnerOrdersController.nextStatuses(OrderStatus.ready),
        [OrderStatus.pickedUp, OrderStatus.onTheWay]);
  });

  test('order screen: no "delivered" for an order a driver carries', () {
    for (final s in inTransit) {
      for (final skips in [true, false]) {
        expect(OrderDetailController.nextStatuses(s, skipsPreparation: skips), isEmpty);
        expect(OrderDetailController.nextStatuses(s, skipsPreparation: skips, selfDelivery: true),
            [OrderStatus.delivered]);
      }
    }
  });

  test('the update buttons appear only when there is a status to offer', () {
    final card = File('lib/features/orders/presentation/partner_orders/widgets/order_card.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final screen = File('lib/features/orders/presentation/order_detail/order_detail_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(card, contains('selfDelivery: order.selfDelivery)\n                  .isNotEmpty)'));
    expect(screen, contains('if (canUpdate)'));
    expect(screen, isNot(contains('isOpen')));
    expect(RegExp(r'nextStatusesFor\(order\.status, selfDelivery: order\.selfDelivery\)').allMatches(screen).length, 2);
  });
}
