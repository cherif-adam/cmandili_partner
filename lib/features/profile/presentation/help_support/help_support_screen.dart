import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'help_support_controller.dart';

/// "Aide & support", top to bottom:
///   _Intro           title and short explanation
///   _TicketFields    subject, message
///   _SubmitButton
///   _ContactOptions  e-mail and phone
///
/// UI only: sending the ticket lives in [HelpSupportController].
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  /// This screen's own controller (see [helpSupportControllerProvider]).
  late final _provider = helpSupportControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isSubmitting = ref.watch(_provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.helpSupport,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Intro(),
              const SizedBox(height: 30),
              _TicketFields(
                subjectController: _subjectController,
                messageController: _messageController,
              ),
              const SizedBox(height: 40),
              _SubmitButton(
                isSubmitting: isSubmitting,
                onPressed: _submitTicket,
              ),
              const SizedBox(height: 30),
              const _ContactOptions(),
            ],
          ),
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(_provider.notifier).submit(
            subject: _subjectController.text,
            message: _messageController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.supportTicketSent),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSendTicket),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.howCanWeHelp,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          l.fillFormDescription,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TicketFields extends StatelessWidget {
  const _TicketFields({
    required this.subjectController,
    required this.messageController,
  });

  final TextEditingController subjectController;
  final TextEditingController messageController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: subjectController,
          decoration: InputDecoration(
            labelText: l.subject,
            prefixIcon:
                const Icon(Icons.title, color: AppColors.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) => HelpSupportController.isMissing(value)
              ? 'Please enter a subject'
              : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: messageController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l.message,
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 100),
              child: Icon(Icons.message_outlined,
                  color: AppColors.primary),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) => HelpSupportController.isMissing(value)
              ? 'Please enter your message'
              : null,
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isSubmitting, required this.onPressed});

  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ElevatedButton(
      onPressed: isSubmitting ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child:
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(l.submitTicket,
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
    );
  }
}

/// The e-mail and phone to reach the team directly.
class _ContactOptions extends StatelessWidget {
  const _ContactOptions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContactOption(
          icon: Icons.email_outlined,
          title: l.emailUs,
          subtitle: 'firasmzoughi2001@gmail.com',
        ),
        _ContactOption(
          icon: Icons.phone_outlined,
          title: l.callUs,
          subtitle: '+216 71 123 456',
        ),
      ],
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
