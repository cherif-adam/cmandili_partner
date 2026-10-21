import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';

/// The item's photo: the one picked on the phone, else the saved one, else
/// an invitation to add one. Tapping opens the gallery.
class ItemImagePicker extends StatelessWidget {
  const ItemImagePicker({
    super.key,
    required this.imageFile,
    required this.imageUrl,
    required this.onTap,
  });

  final File? imageFile;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textLight.withOpacity(0.15),
            width: 1.5,
          ),
          image: imageFile != null
              ? DecorationImage(
                  image: FileImage(imageFile!),
                  fit: BoxFit.cover,
                )
              : (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: (imageFile == null && imageUrl.isEmpty)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 40),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.tapUploadDishPicture, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
      ),
    );
  }
}
