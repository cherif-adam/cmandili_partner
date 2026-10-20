import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/localization_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

/// The profile tab's actions. It has no state of its own: what it shows is
/// the profile, the language and the theme, each from its own provider.
/// Kept alive by the screen watching it.
final profileControllerProvider =
    NotifierProvider.autoDispose<ProfileController, void>(ProfileController.new);

class ProfileController extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  // ── User actions ──────────────────────────────────────────────────────────

  /// Signs out for real; main.dart then shows the sign-in screen. The screen
  /// first goes back to the root route (see ProfileScreen).
  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      debugPrint('Deconnexion echouee : $e');
    }
  }

  void setLanguage(String code) =>
      ref.read(localizationProvider.notifier).setLocale(Locale(code));

  void toggleTheme() => ref.read(themeProvider.notifier).toggleTheme();
}
