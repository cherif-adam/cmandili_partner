import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per setup screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final partnerOnboardingControllerProvider = NotifierProvider.autoDispose
    .family<PartnerOnboardingController, PartnerOnboardingState, Object>(
        PartnerOnboardingController.new);

@immutable
class PartnerOnboardingState {
  const PartnerOnboardingState({
    this.partnerType = 'restaurant',
    this.isLoading = false,
  });

  final String partnerType;
  final bool isLoading;
}

class PartnerOnboardingController
    extends AutoDisposeFamilyNotifier<PartnerOnboardingState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  PartnerOnboardingState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const PartnerOnboardingState();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void selectType(String? type) => state = PartnerOnboardingState(
        partnerType: type ?? 'restaurant',
        isLoading: state.isLoading,
      );

  /// Creates the shop with [name] (trimmed; nothing happens when empty).
  /// Returns null on success, or the error. On success the profile is
  /// reloaded, so the home screen moves on to the dashboard.
  Future<Object?> submit(String name) async {
    if (name.trim().isEmpty) return null;

    final authRepository = ref.read(authRepositoryProvider);
    _setLoading(true);
    try {
      await authRepository.completeOnboarding(
        name.trim(),
        state.partnerType,
      );
      // Invalidate the profile provider so the home screen will transition to the dashboard
      ref.invalidate(partnerProfileProvider);
      return null;
    } catch (e) {
      return e;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    state = PartnerOnboardingState(
      partnerType: state.partnerType,
      isLoading: value,
    );
  }
}
