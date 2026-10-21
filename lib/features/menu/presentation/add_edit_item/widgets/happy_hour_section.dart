import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'item_form_fields.dart';

/// The Happy Hour block: the on/off switch, then (when on) its price and
/// its start and end times.
class HappyHourSection extends StatelessWidget {
  const HappyHourSection({
    super.key,
    required this.isHappyHour,
    required this.priceController,
    required this.start,
    required this.end,
    required this.onToggle,
    required this.onStart,
    required this.onEnd,
  });

  final bool isHappyHour;
  final TextEditingController priceController;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onStart;
  final ValueChanged<TimeOfDay> onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHappyHour ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHappyHour ? AppColors.primary.withOpacity(0.3) : AppColors.textLight.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: isHappyHour,
            onChanged: onToggle,
            activeColor: AppColors.primary,
            title: const Text('Activer Happy Hour',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            subtitle: const Text('Offre spéciale à durée limitée',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isHappyHour ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration_outlined,
                  color: isHappyHour ? AppColors.primary : AppColors.textSecondary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          if (isHappyHour) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ItemTextField(
                    priceController,
                    'Prix Happy Hour (DT)',
                    Icons.sell_outlined,
                    inputType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ItemTimePickerField(
                          'Heure de début',
                          start,
                          onStart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ItemTimePickerField(
                          'Heure de fin',
                          end,
                          onEnd,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
