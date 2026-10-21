import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// A white card with a small grey title, used by every part of the order
/// screen.
class DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  const DetailSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A label and an amount in DT, bold for the total.
class PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  const PriceRow({super.key, required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.textPrimary : AppColors.textSecondary)),
        Text('${value.toStringAsFixed(2)} DT', style: TextStyle(fontSize: isBold ? 17 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}
