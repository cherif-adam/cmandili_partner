import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Editable row in the variants list. Wraps a name + price controller plus
/// the original variant id (empty string for newly-added rows). Held by the
/// screen's State so controllers are disposed in the State's dispose().
class VariantDraft {
  final String id; // empty for new rows
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  bool isAvailable;

  VariantDraft({
    this.id = '',
    String name = '',
    double? price,
    this.isAvailable = true,
  })  : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(
          text: price == null ? '' : price.toStringAsFixed(2),
        );

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// The variant rows (name, price, remove), or a note when there are none.
class VariantsList extends StatelessWidget {
  const VariantsList({super.key, required this.variants, required this.onRemove});

  final List<VariantDraft> variants;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: AppColors.textLight),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No variants. Tap "Add variant" to give customers choices.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: List.generate(variants.length, (i) {
        final v = variants[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: v.nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Chocolate',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: v.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price (DT)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => onRemove(i),
              ),
            ],
          ),
        );
      }),
    );
  }
}
