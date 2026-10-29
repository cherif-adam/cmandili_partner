import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../order_detail/order_detail_screen.dart';
import '../partner_orders_controller.dart';
import 'status_option.dart';

/// One order in the list: first item and customer, time and status, total,
/// and the status sheet. Tapping opens the order.
class OrderCard extends ConsumerWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(order.status);
    // Resolved customer name from orders_with_customer view; fall back to the
    // address label, then a generic placeholder.
    final customerName = (order.customerName?.isNotEmpty ?? false)
        ? order.customerName!
        : (order.deliveryAddress.recipientName?.isNotEmpty ?? false)
            ? order.deliveryAddress.recipientName!
            : (order.deliveryAddress.label.isNotEmpty
                ? order.deliveryAddress.label
                : 'Customer');

    // First item name + overflow count — mirrors the dashboard card logic.
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final imageUrl = firstItem?.imageUrl ?? '';
    final String orderTitle;
    if (firstItem == null) {
      orderTitle = '#${order.id.substring(0, 8).toUpperCase()}';
    } else {
      final extra = order.items.length - 1;
      orderTitle = extra > 0
          ? '${firstItem.displayName} + $extra item(s)'
          : firstItem.displayName;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Item thumbnail with shopping-bag fallback — same as dashboard.
              SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: statusColor.withOpacity(0.08),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _itemFallback(statusColor),
                        )
                      : _itemFallback(statusColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$customerName • ${order.items.isEmpty ? "Order" : "${order.items.length} item(s)"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.getStatusText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${order.total.toStringAsFixed(2)} DT',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (PartnerOrdersController.nextStatuses(order.status, selfDelivery: order.selfDelivery)
                  .isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showStatusSheet(context, ref),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(AppLocalizations.of(context)!.updateStatus),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _itemFallback(Color statusColor) {
    return Container(
      color: statusColor.withOpacity(0.12),
      child: Icon(Icons.shopping_bag_rounded, color: statusColor),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    final nextStatuses =
        PartnerOrdersController.nextStatuses(order.status, selfDelivery: order.selfDelivery);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(ctx)!.updateOrderStatus,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '#${order.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ...nextStatuses.map((status) => StatusOption(
                  status: status,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(partnerOrdersControllerProvider.notifier)
                          .updateStatus(order.id, status);
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                          'Order updated to ${status.toString().split('.').last}',
                        ),
                        backgroundColor: AppColors.success,
                      ));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(
                        content: Text('Failed to update order: $e'),
                        backgroundColor: AppColors.error,
                      ));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.primary;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.warning;
      case OrderStatus.ready:
        return AppColors.accent;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return AppColors.secondary;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
