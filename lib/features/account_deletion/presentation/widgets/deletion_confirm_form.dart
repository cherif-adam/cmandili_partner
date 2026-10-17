import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/models/deletion_outcome.dart';
import '../../providers/account_deletion_provider.dart';

/// Confirmation : taper le mot (SUPPRIMER, DELETE, حذف selon la langue), puis
/// prouver que c'est bien soi — mot de passe, ou reconnexion Google pour un
/// compte sans mot de passe. Le serveur refuse si cette preuve date de plus
/// de 5 minutes.
class DeletionConfirmForm extends ConsumerStatefulWidget {
  /// Le serveur a trouvé un blocage au dernier moment (une commande arrivée
  /// pendant que l'écran était ouvert) : l'écran relit la liste.
  final VoidCallback onBlockedLate;

  const DeletionConfirmForm({super.key, required this.onBlockedLate});

  @override
  ConsumerState<DeletionConfirmForm> createState() => _DeletionConfirmFormState();
}

class _DeletionConfirmFormState extends ConsumerState<DeletionConfirmForm> {
  final _formKey = GlobalKey<FormState>();
  final _wordCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _wordMatches(String? value, String word) =>
      (value ?? '').trim().toUpperCase() == word.toUpperCase();

  String _reauthError(AppLocalizations l, String code) {
    switch (code) {
      case 'wrong_password':
        return l.deleteAccountErrorWrongPassword;
      case 'other_account':
        return l.deleteAccountErrorOtherGoogle;
      default:
        return l.deleteAccountErrorFailed;
    }
  }

  Future<void> _submit(String method) async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = ref.read(authRepositoryProvider);
    final reauth = method == 'password'
        ? await auth.reauthenticateWithPassword(_passwordCtrl.text)
        : await auth.reauthenticateWithGoogle();
    if (!mounted) return;
    if (reauth != null) {
      setState(() {
        _busy = false;
        // Fermer le sélecteur Google n'est pas une erreur.
        _error = reauth == 'cancelled' ? null : _reauthError(l, reauth);
      });
      return;
    }

    final outcome = await ref.read(accountDeletionRepositoryProvider).deleteAccount();
    if (!mounted) return;

    switch (outcome.status) {
      case DeletionStatus.deleted:
        await _finish(l);
        return;
      case DeletionStatus.blocked:
        setState(() => _busy = false);
        widget.onBlockedLate();
        return;
      case DeletionStatus.reauthRequired:
        setState(() {
          _busy = false;
          _error = l.deleteAccountErrorReauth;
        });
        return;
      case DeletionStatus.failed:
        setState(() {
          _busy = false;
          _error = l.deleteAccountErrorFailed;
        });
        return;
    }
  }

  /// Le compte n'existe plus côté serveur. On le dit, puis on revient à la
  /// racine avant de nettoyer la session : c'est elle que main.dart bascule
  /// sur l'écran de connexion (même raison que la déconnexion du profil).
  Future<void> _finish(AppLocalizations l) async {
    final auth = ref.read(authRepositoryProvider);
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteAccountDoneTitle),
        content: Text(l.deleteAccountDoneBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.deleteAccountDoneOk),
          ),
        ],
      ),
    );
    navigator.popUntil((route) => route.isFirst);
    await auth.signOutAfterDeletion();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final method = ref.read(authRepositoryProvider).reauthMethod;
    final word = l.deleteAccountConfirmWord;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.deleteAccountTypeWord(word),
            style: TextStyle(fontSize: width * 0.038, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: width * 0.02),
          TextFormField(
            controller: _wordCtrl,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: word,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => _wordMatches(v, word) ? null : l.deleteAccountWordMismatch(word),
          ),
          SizedBox(height: width * 0.045),
          if (method == 'password') ...[
            Text(l.deleteAccountPasswordHint, style: TextStyle(fontSize: width * 0.036)),
            SizedBox(height: width * 0.02),
            TextFormField(
              controller: _passwordCtrl,
              enabled: !_busy,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.deleteAccountPasswordLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? l.deleteAccountErrorWrongPassword : null,
            ),
          ] else if (method == 'google')
            Text(l.deleteAccountGoogleHint, style: TextStyle(fontSize: width * 0.036))
          else
            Text(
              l.deleteAccountErrorNoMethod,
              style: TextStyle(fontSize: width * 0.036, color: AppColors.error),
            ),
          if (_error != null) ...[
            SizedBox(height: width * 0.03),
            Text(_error!, style: TextStyle(fontSize: width * 0.035, color: AppColors.error)),
          ],
          SizedBox(height: width * 0.05),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: width * 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(width * 0.03)),
            ),
            onPressed: (_busy || method == null) ? null : () => _submit(method),
            child: _busy
                ? SizedBox(
                    height: width * 0.05,
                    width: width * 0.05,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l.deleteAccountSubmit,
                    style: TextStyle(fontSize: width * 0.04, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
