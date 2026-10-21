import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/localization_provider.dart';
import '../../providers/auth_provider.dart';

/// One controller per sign-in screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final authScreenControllerProvider = NotifierProvider.autoDispose
    .family<AuthScreenController, AuthScreenState, Object>(AuthScreenController.new);

@immutable
class AuthScreenState {
  const AuthScreenState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.partnerType = 'restaurant',
  });

  final bool isLoading;
  final bool obscurePassword;

  /// The shop type picked on the sign-up tab.
  final String partnerType;

  AuthScreenState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    String? partnerType,
  }) =>
      AuthScreenState(
        isLoading: isLoading ?? this.isLoading,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        partnerType: partnerType ?? this.partnerType,
      );
}

/// What an e-mail sign-in / sign-up led to (errors throw instead).
enum EmailAuthOutcome {
  /// A session is open: the app can show the dashboard.
  signedIn,

  /// Account created but no session: the project requires the partner to
  /// confirm their e-mail first.
  needsEmailConfirmation,
}

class AuthScreenController
    extends AutoDisposeFamilyNotifier<AuthScreenState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  AuthScreenState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const AuthScreenState();
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    state = state.copyWith(isLoading: value);
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void selectPartnerType(String type) => state = state.copyWith(partnerType: type);

  /// Cycle through languages: en -> ar -> fr -> en
  void cycleLanguage(String currentCode) {
    String nextLang;
    switch (currentCode) {
      case 'en':
        nextLang = 'ar';
        break;
      case 'ar':
        nextLang = 'fr';
        break;
      default:
        nextLang = 'en';
    }
    ref.read(localizationProvider.notifier).setLocale(Locale(nextLang));
  }

  /// Signs in ([isSignIn]) or creates the account with the sign-up fields
  /// and the picked shop type. E-mail, name and phone are trimmed, the
  /// password is not. Errors throw: pass them to [friendlyAuthErrorMessage].
  Future<EmailAuthOutcome> submitEmail({
    required bool isSignIn,
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _setLoading(true);
    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (isSignIn) {
        await authRepo
            .signInWithEmail(
              email.trim(),
              password,
            )
            // Sans delai maximum, une requete qui ne revient jamais laisse
            // _isLoading a true -- et le bouton, desactive pendant le
            // chargement, ne repond plus du tout.
            .timeout(const Duration(seconds: 25));
        return EmailAuthOutcome.signedIn;
      }

      await authRepo.signUpWithEmail(
        email.trim(),
        password,
        name.trim(),
        state.partnerType,
        phone.trim(),
      );
      // Compte cree mais pas de session : le projet exige une confirmation
      // par email. On le dit, au lieu de laisser le formulaire muet.
      return authRepo.hasSession
          ? EmailAuthOutcome.signedIn
          : EmailAuthOutcome.needsEmailConfirmation;
    } finally {
      _setLoading(false);
    }
  }

  /// Google sign-in. Returns whether a session is open afterwards. Errors
  /// throw: pass them to [friendlyAuthErrorMessage].
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      return authRepo.hasSession;
    } finally {
      _setLoading(false);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Maps a raw auth exception (e.g. the Supabase client's
/// `AuthApiException(message: Invalid login credentials, statusCode: 400,
/// code: invalid_credentials)`) to a short message a partner can actually
/// act on. Matched on the exception's own toString() rather than importing
/// the exception type, since the client only needs a handful of known
/// substrings and this keeps the check trivially portable.
String friendlyAuthErrorMessage(Object e) {
  final raw = e.toString().toLowerCase();
  if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) {
    return 'Email ou mot de passe incorrect';
  }
  if (raw.contains('user already registered') || raw.contains('already registered')) {
    return 'Un compte existe déjà avec cet email';
  }
  if (raw.contains('email not confirmed')) {
    return 'Veuillez confirmer votre email avant de vous connecter';
  }
  if (raw.contains('password') && raw.contains('6 characters')) {
    return 'Le mot de passe doit contenir au moins 6 caractères';
  }
  if (raw.contains('socketexception') ||
      raw.contains('network') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection')) {
    return 'Problème de connexion internet';
  }
  // Serveur injoignable ou en panne : 502/503/504 et les délais dépassés.
  // Sans ces cas, une panne Supabase tombait dans le message generique
  // « une erreur est survenue », qui laisse croire a une faute de saisie.
  if (raw.contains('timeout') || raw.contains('timed out')) {
    return 'Le serveur met trop de temps à répondre. Réessayez.';
  }
  if (raw.contains('statuscode: 50') ||
      raw.contains('502') ||
      raw.contains('503') ||
      raw.contains('504') ||
      raw.contains('service unavailable') ||
      raw.contains('bad gateway')) {
    return 'Le service est momentanément indisponible. Réessayez dans un instant.';
  }
  return 'Une erreur est survenue, veuillez réessayer';
}
