import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order.dart';
import 'order_detail_controller.dart';
import 'widgets/cancel_reason_sheet.dart';
import 'widgets/customer_section.dart';
import 'widgets/detail_section.dart';
import 'widgets/order_item_row.dart';
import 'widgets/order_status_style.dart';
import 'widgets/payment_status_section.dart';
import 'widgets/self_delivery_banner.dart';
import 'widgets/status_sheet.dart';

/// One order, as the shop sees it: status, customer, address, payment,
/// notes, items, prices, driver, where the money stands, then the actions
/// (self-delivery, next status, cancel).
class OrderDetailScreen extends ConsumerWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(orderDetailControllerProvider.notifier);
    final isOpen = order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled;
    final showBanner = OrderDetailController.showSelfDeliveryBanner(order);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('#${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      // One list entry per part, as before: the list builds only the parts
      // near the screen (the voice note players among them).
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusBanner(
            order: order,
            onUpdate: isOpen ? () => _showStatusSheet(context, ref) : null,
          ),

          const SizedBox(height: 16),

          CustomerSection(order: order),

          const SizedBox(height: 12),

          _AddressSection(order: order),

          const SizedBox(height: 12),

          _PaymentSection(order: order),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NotesSection(notes: order.notes!),
          ],

          const SizedBox(height: 12),

          _ItemsSection(order: order),

          const SizedBox(height: 12),

          _PriceBreakdownSection(order: order),

          if (order.driverId != null) ...[
            const SizedBox(height: 12),
            _DriverSection(order: order),
          ],

          // Money trail: answers "has the driver collected, and what is my
          // share?" without the partner having to ask anyone. Commission is
          // only ever charged once the cash is actually in hand, so an order
          // that is still in transit shows as pending rather than as a debt.
          const SizedBox(height: 12),
          PaymentStatusSection(order: order),

          const SizedBox(height: 24),

          // Self-delivery banner: shown when the waterfall failed and the
          // partner hasn't committed to self-delivery yet.
          if (showBanner)
            SelfDeliveryBanner(order: order),

          if (showBanner) const SizedBox(height: 12),

          // Action buttons for non-final statuses
          if (isOpen)
            _UpdateStatusButton(onPressed: () => _showStatusSheet(context, ref)),

          // Cancel stays available only while the food is still in the shop.
          // After pickup the driver is already carrying it, so cancelling
          // would strand a delivery the customer is waiting on.
          if (OrderDetailController.canPartnerCancel(order)) ...[
            const SizedBox(height: 12),
            _CancelButton(onPressed: () => _cancel(context, ref)),
          ],
        ],
      ),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    showStatusSheet(
      context: context,
      statuses: ref
          .read(orderDetailControllerProvider.notifier)
          .nextStatusesFor(order.status),
      onPick: (s) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(orderDetailControllerProvider.notifier).updateStatus(order.id, s);
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          messenger.showSnackBar(SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      },
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await showCancelReasonSheet(
        context, OrderDetailController.partnerCancelReasons);

    if (reason == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await ref
          .read(orderDetailControllerProvider.notifier)
          .cancel(order.id, reason);
      if (!context.mounted) return;
      if (ok) {
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(
          content: Text('Commande annulée.'),
          backgroundColor: AppColors.error,
        ));
      } else {
        // Someone moved the order on while the sheet was open.
        messenger.showSnackBar(const SnackBar(
          content: Text(
              "Trop tard : la commande n'est plus annulable. Actualisez."),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de l\'annulation : $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

// ── Sections, in screen order ────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.order, required this.onUpdate});

  final Order order;

  /// Null once the order is delivered or cancelled.
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.status);
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(orderStatusIcon(order.status), color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.getStatusText(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_formatDateTime(order.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (onUpdate != null)
            TextButton(
              onPressed: onUpdate,
              child: Text(l.update),
            ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: l.deliveryAddress,
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              order.deliveryAddress.fullAddress.isNotEmpty
                  ? order.deliveryAddress.fullAddress
                  : order.deliveryAddress.label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: l.payment,
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Text(order.paymentMethod, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(
            '${order.total.toStringAsFixed(2)} DT',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: l.customerNotes,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.note_outlined, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(notes, style: const TextStyle(color: Colors.orange, fontSize: 14))),
        ],
      ),
    );
  }
}

/// Order items with customizations.
class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: '${l.items} (${order.items.length})',
      child: Column(
        children: [
          for (var i = 0; i < order.items.length; i++)
            OrderItemRow(item: order.items[i], isLast: i == order.items.length - 1),
        ],
      ),
    );
  }
}

class _PriceBreakdownSection extends StatelessWidget {
  const _PriceBreakdownSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: l.priceBreakdown,
      child: Column(
        children: [
          PriceRow(label: 'Subtotal', value: order.subtotal),
          const SizedBox(height: 8),
          PriceRow(label: l.deliveryFee, value: order.deliveryFee),
          const Divider(height: 20),
          PriceRow(label: l.total, value: order.total, isBold: true),
        ],
      ),
    );
  }
}

class _DriverSection extends StatelessWidget {
  const _DriverSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DetailSection(
      title: l.driver,
      child: Row(
        children: [
          const Icon(Icons.delivery_dining, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(order.driverName ?? l.assigned, style: const TextStyle(fontSize: 15)),
          if (order.driverPhone != null) ...[
            const Spacer(),
            Text(order.driverPhone!, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _UpdateStatusButton extends StatelessWidget {
  const _UpdateStatusButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(l.updateOrderStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.cancel_outlined, size: 20),
        label: const Text('Annuler la commande',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
