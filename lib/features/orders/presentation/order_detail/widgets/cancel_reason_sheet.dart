import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Asks why the shop cancels; null when the sheet is closed without a
/// choice.
Future<String?> showCancelReasonSheet(BuildContext context, List<String> reasons) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Annuler la commande',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Le client sera prévenu immédiatement. '
              'Aucune commission ne sera prélevée.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            ...reasons.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.pop(ctx, r),
                )),
          ],
        ),
      ),
    ),
  );
}
