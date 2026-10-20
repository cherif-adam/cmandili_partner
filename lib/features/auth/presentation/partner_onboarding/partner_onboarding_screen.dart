import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/partner_model.dart';
import 'partner_onboarding_controller.dart';

/// "Terminer la configuration", top to bottom: _Welcome, _BusinessForm
/// (shop name, shop type), _SubmitButton.
///
/// UI only: the chosen type and creating the shop live in
/// [PartnerOnboardingController].
class PartnerOnboardingScreen extends ConsumerStatefulWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  ConsumerState<PartnerOnboardingScreen> createState() => _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends ConsumerState<PartnerOnboardingScreen> {
  /// This screen's own controller (see [partnerOnboardingControllerProvider]).
  late final _provider = partnerOnboardingControllerProvider(Object());

  final _nameController = TextEditingController();

  Future<void> _submit() async {
    final error = await ref.read(_provider.notifier).submit(_nameController.text);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(_provider);
    return Scaffold(
      appBar: AppBar(title: Text(l.completeSetup)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Welcome(),
            const SizedBox(height: 32),
            _BusinessForm(
              nameController: _nameController,
              partnerType: state.partnerType,
              onTypeChanged: ref.read(_provider.notifier).selectType,
            ),
            const SizedBox(height: 32),
            _SubmitButton(isLoading: state.isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.welcomeExclamation,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l.provideBusinessDetails,
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BusinessForm extends StatelessWidget {
  const _BusinessForm({
    required this.nameController,
    required this.partnerType,
    required this.onTypeChanged,
  });

  final TextEditingController nameController;
  final String partnerType;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l.businessName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: partnerType,
          items: [
            // Driven by kPartnerTypes so a newly launched shop type
            // appears here and in the email sign-up form together. The
            // two original entries keep their translated labels; the
            // newer ones carry their own, since they have no l10n keys.
            for (final option in kPartnerTypes)
              DropdownMenuItem(
                value: option.type,
                child: Text(switch (option.type) {
                  'restaurant' => l.restaurant,
                  'supermarket' => l.supermarket,
                  _ => '${option.icon}  ${option.label}',
                }),
              ),
          ],
          onChanged: onTypeChanged,
          decoration: InputDecoration(
            labelText: l.businessType,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : Text(l.completeSetup),
    );
  }
}
