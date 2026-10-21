import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

/// A status the order can move to, in the card's status sheet.
class StatusOption extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onTap;
  const StatusOption({super.key, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = _label(status, context);
    final color = _color(status);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_icon(status), color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _label(OrderStatus s, BuildContext context) {
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

  IconData _icon(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed: return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing: return Icons.restaurant_rounded;
      case OrderStatus.ready: return Icons.done_all_rounded;
      case OrderStatus.pickedUp: return Icons.directions_bike_rounded;
      case OrderStatus.onTheWay: return Icons.delivery_dining_rounded;
      case OrderStatus.delivered: return Icons.home_rounded;
      case OrderStatus.cancelled: return Icons.cancel_outlined;
      default: return Icons.circle_outlined;
    }
  }

  Color _color(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed: return AppColors.info;
      case OrderStatus.preparing: return AppColors.warning;
      case OrderStatus.ready: return AppColors.accent;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay: return AppColors.secondary;
      case OrderStatus.delivered: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
      default: return AppColors.primary;
    }
  }
}
