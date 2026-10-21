import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

/// The colour, icon and action label of each order status on the order
/// screen.
Color orderStatusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending: return AppColors.primary;
    case OrderStatus.confirmed: return AppColors.info;
    case OrderStatus.preparing: return AppColors.warning;
    case OrderStatus.ready: return AppColors.accent;
    case OrderStatus.pickedUp:
    case OrderStatus.onTheWay: return AppColors.secondary;
    case OrderStatus.delivered: return AppColors.success;
    case OrderStatus.cancelled: return AppColors.error;
  }
}

IconData orderStatusIcon(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending: return Icons.hourglass_empty_rounded;
    case OrderStatus.confirmed: return Icons.check_circle_outline_rounded;
    case OrderStatus.preparing: return Icons.restaurant_rounded;
    case OrderStatus.ready: return Icons.done_all_rounded;
    case OrderStatus.pickedUp: return Icons.directions_bike_rounded;
    case OrderStatus.onTheWay: return Icons.delivery_dining_rounded;
    case OrderStatus.delivered: return Icons.home_rounded;
    case OrderStatus.cancelled: return Icons.cancel_outlined;
  }
}

String orderStatusLabel(OrderStatus s, BuildContext context) {
  final l = AppLocalizations.of(context)!;
  switch (s) {
    case OrderStatus.confirmed: return l.confirmOrder;
    case OrderStatus.preparing: return l.startPreparing;
    case OrderStatus.ready: return l.markAsReady;
    case OrderStatus.pickedUp: return l.pickedUp;
    case OrderStatus.onTheWay: return l.outForDelivery;
    case OrderStatus.delivered: return l.markAsDelivered;
    case OrderStatus.cancelled: return l.cancelOrder;
    default: return s.toString().split('.').last;
  }
}
