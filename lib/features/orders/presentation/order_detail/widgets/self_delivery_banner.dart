import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../order_detail_controller.dart';

/// Shown when the waterfall found no driver: the partner can take the
/// delivery on themself.
class SelfDeliveryBanner extends ConsumerWidget {
  final Order order;
  const SelfDeliveryBanner({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(orderDetailControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucun livreur disponible',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Voulez-vous livrer cette commande vous-même ?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _onConfirmSelfDelivery(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.orange.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Je livre cette commande',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirmSelfDelivery(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(orderDetailControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.confirmSelfDelivery(order.id);
    if (error == null) {
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Vous êtes maintenant en livraison. Marquez la commande comme livrée une fois remise.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ));
      }
    } else {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur: $error'),
          backgroundColor: AppColors.error,
        ));
      }
    }
    if (context.mounted) {
      ref.read(orderDetailControllerProvider.notifier).selfDeliveryDone();
    }
  }
}
