import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'edit_profile_controller.dart';

/// "Modifier le profil", top to bottom:
///   _AvatarPicker    photo with the camera button
///   _ProfileFields   business name, address, e-mail (read-only), phone, bio
///   _SaveButton
///
/// UI only: the picked photo, the upload and the save live in
/// [EditProfileController].
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  /// This screen's own controller (see [editProfileControllerProvider]).
  late final _provider = editProfileControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _addressController;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(_provider.notifier).initialValues();
    _nameController = TextEditingController(text: initial.name);
    _emailController = TextEditingController(text: initial.email);
    _phoneController = TextEditingController(text: initial.phone);
    _bioController = TextEditingController(text: initial.bio);
    _addressController = TextEditingController(text: initial.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final state = ref.watch(_provider);
    final photoUrl = ref.read(_provider.notifier).photoUrl;

    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.editProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.05),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _AvatarPicker(
                imageFile: state.imageFile,
                photoUrl: photoUrl,
                onPick: _pickImage,
              ),
              SizedBox(height: size.height * 0.04),
              _ProfileFields(
                nameController: _nameController,
                addressController: _addressController,
                emailController: _emailController,
                phoneController: _phoneController,
                bioController: _bioController,
              ),
              SizedBox(height: size.height * 0.05),
              _SaveButton(isLoading: state.isLoading, onPressed: _saveProfile),
            ],
          ),
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final controller = ref.read(_provider.notifier);
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      controller.setImage(File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final controller = ref.read(_provider.notifier);
      final outcome = await controller.save(
        onAvatarFailed: () {
          if (!mounted) return;
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.warningAvatarFailed), backgroundColor: AppColors.warning),
          );
        },
        readFields: () => (
          name: _nameController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          bio: _bioController.text,
        ),
      );

      if (outcome == EditProfileOutcome.noProfile || !mounted) return;
      final l = AppLocalizations.of(context)!;
      if (outcome == EditProfileOutcome.updated) {
        controller.refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.profileUpdated), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.failedToUpdateProfile), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.imageFile,
    required this.photoUrl,
    required this.onPick,
  });

  final File? imageFile;
  final String? photoUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Center(
      child: Stack(
        children: [
          Container(
            width: size.width * 0.3,
            height: size.width * 0.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              image: imageFile != null
                  ? DecorationImage(
                      image: FileImage(imageFile!),
                      fit: BoxFit.cover,
                    )
                  : photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFields extends StatelessWidget {
  const _ProfileFields({
    required this.nameController,
    required this.addressController,
    required this.emailController,
    required this.phoneController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController bioController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        _ProfileTextField(
          controller: nameController,
          label: AppLocalizations.of(context)!.businessName,
          icon: Icons.storefront_outlined,
          validator: (value) => value!.isEmpty ? 'Please enter your business name' : null,
        ),
        SizedBox(height: size.height * 0.02),

        _ProfileTextField(
          controller: addressController,
          label: 'Restaurant Address',
          icon: Icons.location_on_outlined,
          validator: (value) => value!.isEmpty ? 'Please enter your address' : null,
        ),
        SizedBox(height: size.height * 0.02),

        _ProfileTextField(
          controller: emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: false, // Email usually not editable directly
        ),
        SizedBox(height: size.height * 0.02),

        _ProfileTextField(
          controller: phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: size.height * 0.02),

        _ProfileTextField(
          controller: bioController,
          label: 'Bio',
          icon: Icons.info_outline,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }
}
