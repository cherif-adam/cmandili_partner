import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';

/// Name + emoji for a new category. [onCreate] gets them when the name is
/// not empty; the dialog then closes, and so does the route under it
/// ([context]'s top route).
void showNewCategoryDialog({
  required BuildContext context,
  required void Function(String name, String emoji) onCreate,
}) {
  final nameCtrl = TextEditingController();

  // Emojis the user can pick for their new category
  const emojiOptions = ['🍽️', '🍕', '🍔', '🌮', '🍜', '🍣', '🥘', '🍱', '🧆', '🥙', '🍗', '🍖',
                        '🥐', '🍩', '🍦', '☕', '🧃', '🍹', '🥗', '🧁', '🫕', '🥨', '🌯', '📁'];
  String selectedEmoji = '🍽️';

  final l = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.createNewCategory, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l.categoryName,
                hintText: l.categoryNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.chooseAnIcon, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojiOptions.map((emoji) {
                final isSelected = selectedEmoji == emoji;
                return InkWell(
                  onTap: () => setDialogState(() => selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              onCreate(name, selectedEmoji);
              Navigator.pop(ctx);
              Navigator.pop(context); // close bottom sheet too
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l.create, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}
