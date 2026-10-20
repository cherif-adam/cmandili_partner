import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/partner_wallet_provider.dart';
import 'payout_controller.dart';

/// "Informations de paiement", top to bottom:
///   _WalletSection   prepaid balance (+ the "blocked" banner at 0)
///   _PayoutNotice    what these details are for
///   _PayoutFields    account holder, bank, IBAN/RIB
///   _SaveButton
///
/// UI only: loading and saving the details live in [PayoutController], the
/// live balance in [partnerWalletProvider].
class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  /// This screen's own controller (see [payoutControllerProvider]).
  late final _provider = payoutControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ref.read(_provider.notifier).load();
    if (saved != null) {
      _bankNameCtrl.text = saved.bankName;
      _ibanCtrl.text = saved.iban;
      _accountHolderCtrl.text = saved.accountHolder;
    }
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _ibanCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final walletAsync = ref.watch(partnerWalletProvider);
    final state = ref.watch(_provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.payoutInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WalletSection(wallet: walletAsync),
                    const SizedBox(height: 24),
                    const _PayoutNotice(),
                    const SizedBox(height: 24),
                    _PayoutFields(
                      accountHolderCtrl: _accountHolderCtrl,
                      bankNameCtrl: _bankNameCtrl,
                      ibanCtrl: _ibanCtrl,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref.read(_provider.notifier).save((
      bankName: _bankNameCtrl.text,
      iban: _ibanCtrl.text,
      accountHolder: _accountHolderCtrl.text,
    ));
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.payoutInfoSaved), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Prepaid balance card + low-balance banner.
class _WalletSection extends StatelessWidget {
  const _WalletSection({required this.wallet});

  final AsyncValue<double?> wallet;

  @override
  Widget build(BuildContext context) {
    return wallet.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (balance) => _PrepaidBalanceCard(balance: balance),
    );
  }
}

class _PayoutNotice extends StatelessWidget {
  const _PayoutNotice();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.payoutInfoMessage,
              style: TextStyle(color: AppColors.primary.withValues(alpha: 0.85), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutFields extends StatelessWidget {
  const _PayoutFields({
    required this.accountHolderCtrl,
    required this.bankNameCtrl,
    required this.ibanCtrl,
  });

  final TextEditingController accountHolderCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController ibanCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PayoutField(
          controller: accountHolderCtrl,
          label: 'Account Holder Name',
          icon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _PayoutField(
          controller: bankNameCtrl,
          label: 'Bank Name',
          icon: Icons.account_balance_outlined,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _PayoutField(
          controller: ibanCtrl,
          label: 'IBAN / RIB',
          icon: Icons.credit_card_outlined,
          keyboardType: TextInputType.text,
          validator: (v) => v!.length < 10 ? 'Enter a valid IBAN/RIB' : null,
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
            : Text(l.savePayoutInfo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _PayoutField extends StatelessWidget {
  const _PayoutField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

/// Prepaid balance summary. When the balance is at or below zero the restaurant
/// is blocked from receiving orders, so we show a prominent red recharge banner.
class _PrepaidBalanceCard extends StatelessWidget {
  final double? balance;

  const _PrepaidBalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final value = balance ?? 0;
    final isBlocked = value <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text('Solde prépayé',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${value.toStringAsFixed(3)} DT',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (isBlocked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre solde est épuisé. Rechargez votre solde pour '
                    'continuer à recevoir des commandes.',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
