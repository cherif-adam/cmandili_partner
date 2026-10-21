import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per "Mot de passe oublié" screen on display (the argument
/// is a key the screen creates for itself), auto-disposed with it like the
/// State it replaces. Its state is "the code is being sent".
final forgotPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ForgotPasswordController, bool, Object>(ForgotPasswordController.new);

/// Why the e-mail is refused. The screen turns it into a text.
enum EmailFieldError { required, invalid }

class ForgotPasswordController extends AutoDisposeFamilyNotifier<bool, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  bool build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Sends the reset code to [email] (trimmed). Returns null on success, or
  /// the error as text.
  Future<String?> sendCode(String email) async {
    final authRepository = ref.read(authRepositoryProvider);
    state = true;
    try {
      await authRepository.sendPasswordResetOtp(email.trim());
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      if (!_disposed) state = false;
    }
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  static EmailFieldError? validateEmail(String? v) {
    if (v == null || v.isEmpty) return EmailFieldError.required;
    if (!v.contains('@')) return EmailFieldError.invalid;
    return null;
  }
}
