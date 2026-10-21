import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import 'detail_section.dart';

/// Where the money for this order stands, from the shop's point of view.
///
/// The partner's recurring question is "when does the driver hand over my
/// money, and what did the platform take?" — previously answerable only by
/// asking an admin. Cash is collected on delivery, so the honest answer has
/// three stages, and the card names whichever one the order is in.
class PaymentStatusSection extends StatelessWidget {
  final Order order;
  const PaymentStatusSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == OrderStatus.cancelled;
    final collected = order.status == OrderStatus.delivered;

    final (Color color, IconData icon, String title, String detail) = cancelled
        ? (
            AppColors.textSecondary,
            Icons.block,
            'Commande annulée',
            'Aucun montant encaissé, aucune commission prélevée.',
          )
        : collected
            ? (
                AppColors.success,
                Icons.check_circle,
                'Encaissé par le livreur',
                'Le livreur a collecté ${order.total.toStringAsFixed(2)} DT. '
                    'Votre part sera versée au prochain règlement.',
              )
            : (
                Colors.orange,
                Icons.schedule,
                'En attente d\'encaissement',
                'La commission n\'est prélevée qu\'une fois '
                    'l\'argent collecté par le livreur.',
              );

    return DetailSection(
      title: 'Paiement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          if (collected) ...[
            const Divider(height: 20),
            PriceRow(label: 'Encaissé', value: order.total),
          ],
        ],
      ),
    );
  }
}
