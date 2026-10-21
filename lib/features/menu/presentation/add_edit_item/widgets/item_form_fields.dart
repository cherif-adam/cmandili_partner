import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// A section title of the item form.
class ItemSectionLabel extends StatelessWidget {
  const ItemSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
    );
  }
}

/// A text field of the item form. [required] adds the "Required" rule
/// when no [validator] is given.
class ItemTextField extends StatelessWidget {
  const ItemTextField(
    this.ctrl,
    this.label,
    this.icon, {
    super.key,
    this.maxLines = 1,
    this.required = false,
    this.inputType,
    this.validator,
  });

  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool required;
  final TextInputType? inputType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textLight.withOpacity(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null),
    );
  }
}

/// An on/off line of the item form.
class ItemSwitchTile extends StatelessWidget {
  const ItemSwitchTile(
    this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.onChanged, {
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      secondary: Icon(icon, color: AppColors.textSecondary, size: 22),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// A time box that opens the time picker; shows [label] until a time is
/// chosen.
class ItemTimePickerField extends StatelessWidget {
  const ItemTimePickerField(this.label, this.time, this.onSelected, {super.key});

  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onSelected;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 18, minute: 0),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (t != null) onSelected(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textLight.withOpacity(0.15), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                time != null ? time.format(context) : label,
                style: TextStyle(
                  fontSize: 14,
                  color: time != null ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: time != null ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
