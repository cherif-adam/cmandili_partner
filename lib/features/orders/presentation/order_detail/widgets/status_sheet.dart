import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import 'order_status_style.dart';

/// The statuses the order can move to; the sheet closes, then [onPick]
/// gets the chosen one.
void showStatusSheet({
  required BuildContext context,
  required List<OrderStatus> statuses,
  required ValueChanged<OrderStatus> onPick,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(ctx)!.updateOrderStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...statuses.map((s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: orderStatusColor(s).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(orderStatusIcon(s), color: orderStatusColor(s), size: 20),
            ),
            title: Text(orderStatusLabel(s, ctx), style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              onPick(s);
            },
          )),
        ],
      ),
    ),
  );
}
