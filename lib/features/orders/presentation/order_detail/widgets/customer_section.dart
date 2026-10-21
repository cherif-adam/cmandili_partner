import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/customer_contact.dart';
import '../../../data/models/order.dart';
import 'detail_section.dart';

/// Who ordered: name and, when known, the number with call and WhatsApp.
class CustomerSection extends StatelessWidget {
  final Order order;
  const CustomerSection({super.key, required this.order});

  String? get _name {
    if ((order.customerName ?? '').isNotEmpty) return order.customerName;
    if ((order.deliveryAddress.recipientName ?? '').isNotEmpty) {
      return order.deliveryAddress.recipientName;
    }
    return null;
  }

  String? get _phone {
    if ((order.customerPhone ?? '').isNotEmpty) return order.customerPhone;
    if ((order.deliveryAddress.phone ?? '').isNotEmpty) {
      return order.deliveryAddress.phone;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = _name ?? l.customer;
    final phone = _phone;
    return DetailSection(
      title: l.customer,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  // Number plus call AND WhatsApp. A single call icon was not
                  // enough: reaching a customer about a missing item or a
                  // wrong address often fails on a voice call and succeeds on
                  // WhatsApp, which works on data alone.
                  CustomerContact(phone: phone, compact: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
