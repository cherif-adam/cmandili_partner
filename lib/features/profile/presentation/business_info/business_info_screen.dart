import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'business_info_controller.dart';

/// "Informations de l'établissement", top to bottom:
///   _LogoPicker       the logo, tap to pick a new one
///   _BusinessFields   name, address, phone, description
///   _SaveButton
///
/// UI only: the logo, the upload and the save live in
/// [BusinessInfoController].
class BusinessInfoScreen extends ConsumerStatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  ConsumerState<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends ConsumerState<BusinessInfoScreen> {
  /// This screen's own controller (see [businessInfoControllerProvider]).
  late final _provider = businessInfoControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    final controller = ref.read(_provider.notifier);
    final initial = controller.initialValues();
    if (initial != null) {
      _nameCtrl.text = initial.name;
      _addressCtrl.text = initial.address;
      _phoneCtrl.text = initial.phone;
      _bioCtrl.text = initial.bio;
    }
    controller.loadExistingLogo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(_provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.businessInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _LogoPicker(
                  pickedLogo: state.pickedLogo,
                  existingLogoUrl: state.existingLogoUrl,
                  onTap: _pickLogo,
                ),
              ),
              const SizedBox(height: 24),
              _BusinessFields(
                nameCtrl: _nameCtrl,
                addressCtrl: _addressCtrl,
                phoneCtrl: _phoneCtrl,
                bioCtrl: _bioCtrl,
              ),
              const SizedBox(height: 32),
              _SaveButton(saving: state.saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final controller = ref.read(_provider.notifier);
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    controller.pickLogo(File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref.read(_provider.notifier).save(() => (
          name: _nameCtrl.text,
          address: _addressCtrl.text,
          phone: _phoneCtrl.text,
          bio: _bioCtrl.text,
        ));
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.businessInfoUpdated), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.pickedLogo,
    required this.existingLogoUrl,
    required this.onTap,
  });

  final File? pickedLogo;
  final String? existingLogoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: pickedLogo != null
                ? Image.file(pickedLogo!, fit: BoxFit.cover)
                : (existingLogoUrl != null && existingLogoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: existingLogoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.storefront_outlined,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                      )
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: AppColors.textLight,
                      )),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessFields extends StatelessWidget {
  const _BusinessFields({
    required this.nameCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.bioCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController bioCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BusinessField(
          controller: nameCtrl,
          label: AppLocalizations.of(context)!.businessName,
          icon: Icons.store_rounded,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _BusinessField(
          controller: addressCtrl,
          label: 'Business Address',
          icon: Icons.location_on_outlined,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _BusinessField(
          controller: phoneCtrl,
          label: 'Contact Phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _BusinessField(
          controller: bioCtrl,
          label: 'Business Description',
          icon: Icons.info_outline,
          maxLines: 4,
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: saving
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _BusinessField extends StatelessWidget {
  const _BusinessField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
