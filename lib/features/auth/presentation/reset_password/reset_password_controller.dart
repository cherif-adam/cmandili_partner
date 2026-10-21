import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per "code de réinitialisation" screen on display (the
/// argument is a key the screen creates for itself), auto-disposed with it
/// like the State it replaces.
final resetPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ResetPasswordController, ResetPasswordState, Object>(
        ResetPasswordController.new);

@immutable
class ResetPasswordState {
  const ResetPasswordState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.obscureConfirm = true,
  });

  final bool isLoading;
  final bool obscurePassword;
  final bool obscureConfirm;

  ResetPasswordState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    bool? obscureConfirm,
  }) =>
      ResetPasswordState(
        isLoading: isLoading ?? this.isLoading,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      );
}

/// Why a field is refused. The screen turns it into a text.
enum ResetFieldError { otpLength, passwordRequired, passwordTooShort, mismatch }

class ResetPasswordController
    extends AutoDisposeFamilyNotifier<ResetPasswordState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  ResetPasswordState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const ResetPasswordState();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void togglePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void toggleConfirm() =>
      state = state.copyWith(obscureConfirm: !state.obscureConfirm);

  /// Verifies the 8-digit [otp] (trimmed), which opens a recovery session,
  /// then sets the new password inside it. [readNewPassword] is read once the
  /// code is verified, as before. Returns null on success, or the message to
  /// show.
  Future<String?> reset({
    required String email,
    required String otp,
    required String Function() readNewPassword,
  }) async {
    state = state.copyWith(isLoading: true);

    final repo = ref.read(authRepositoryProvider);

    try {
      // Step 2: verify OTP → establishes a recovery session in Supabase
      await repo.verifyPasswordResetOtp(
        email: email,
        token: otp.trim(),
      );

      // Step 3: update password within that session
      await repo.updatePassword(readNewPassword());

      return null;
    } catch (e) {
      return friendlyError(e.toString());
    } finally {
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Maps raw Supabase error strings to human-readable messages.
  static String friendlyError(String raw) {
    if (raw.contains('Token has expired') || raw.contains('invalid')) {
      return 'The code is invalid or has expired. Request a new one.';
    }
    if (raw.contains('Password should be')) {
      return 'Password must be at least 6 characters.';
    }
    return raw;
  }

  /// Shows a masked email like  u****@gmail.com
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '$name****'
        : '${name[0]}${'*' * (name.length - 1)}';
    return '$masked@${parts[1]}';
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  static ResetFieldError? validateOtp(String? v) =>
      (v == null || v.trim().length != 8) ? ResetFieldError.otpLength : null;

  static ResetFieldError? validatePassword(String? v) {
    if (v == null || v.isEmpty) return ResetFieldError.passwordRequired;
    if (v.length < 6) return ResetFieldError.passwordTooShort;
    return null;
  }

  static ResetFieldError? validateConfirmation(String? v, String password) =>
      v != password ? ResetFieldError.mismatch : null;
}
