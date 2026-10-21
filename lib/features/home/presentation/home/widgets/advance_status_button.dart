import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../orders/data/models/order.dart';
import '../home_controller.dart';

/// Advances an already-accepted order to its next status straight from the
/// dashboard. Without this the card showed "Preparing" with no control, so the
/// only way to finish an order was to open it from the Orders tab.
class AdvanceStatusButton extends ConsumerStatefulWidget {
  final dynamic order;
  final OrderStatus next;

  const AdvanceStatusButton({super.key, required this.order, required this.next});

  @override
  ConsumerState<AdvanceStatusButton> createState() =>
      _AdvanceStatusButtonState();
}

class _AdvanceStatusButtonState extends ConsumerState<AdvanceStatusButton> {
  bool _busy = false;

  Future<void> _advance() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dashboardControllerProvider.notifier)
          .advance(widget.order.id, widget.next);
      ref.read(dashboardControllerProvider.notifier).refreshOrders();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Échec de la mise à jour : $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _advance,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _actionLabel(widget.next),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

String _actionLabel(OrderStatus next) {
  switch (next) {
    case OrderStatus.preparing:
      return 'Commencer la préparation';
    case OrderStatus.ready:
      return 'Marquer comme prête';
    default:
      return 'Mettre à jour';
  }
}
