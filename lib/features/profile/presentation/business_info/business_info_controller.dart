import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/business_info_repository.dart';

final businessInfoRepositoryProvider =
    Provider<BusinessInfoRepository>((ref) => BusinessInfoRepository());

/// One controller per business-info screen on display (the argument is a key
/// the screen creates for itself), auto-disposed with it like the State it
/// replaces.
final businessInfoControllerProvider = NotifierProvider.autoDispose
    .family<BusinessInfoController, BusinessInfoState, Object>(
        BusinessInfoController.new);

/// What the user typed, untrimmed.
typedef BusinessInfoFields = ({
  String name,
  String address,
  String phone,
  String bio,
});

@immutable
class BusinessInfoState {
  const BusinessInfoState({
    this.saving = false,
    this.pickedLogo,
    this.existingLogoUrl,
  });

  final bool saving;

  /// The new logo picked from the gallery, not uploaded yet.
  final File? pickedLogo;

  /// The logo the shop has now, or null.
  final String? existingLogoUrl;

  /// [pickedLogo] and [existingLogoUrl] are getters so they can be set back
  /// to null.
  BusinessInfoState copyWith({
    bool? saving,
    ValueGetter<File?>? pickedLogo,
    ValueGetter<String?>? existingLogoUrl,
  }) {
    return BusinessInfoState(
      saving: saving ?? this.saving,
      pickedLogo: pickedLogo != null ? pickedLogo() : this.pickedLogo,
      existingLogoUrl:
          existingLogoUrl != null ? existingLogoUrl() : this.existingLogoUrl,
    );
  }
}

class BusinessInfoController
    extends AutoDisposeFamilyNotifier<BusinessInfoState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  BusinessInfoState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const BusinessInfoState();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// The values the fields open with, or null without a profile.
  ({String name, String address, String phone, String bio})? initialValues() {
    final profile = ref.read(partnerProfileProvider).value;
    if (profile == null) return null;
    return (
      name: profile.businessName,
      address: profile.address,
      phone: profile.phone ?? '',
      bio: profile.bio ?? '',
    );
  }

  Future<void> loadExistingLogo() async {
    final profile = ref.read(partnerProfileProvider).value;
    if (profile == null || profile.entityId.isEmpty) return;
    final repository = ref.read(businessInfoRepositoryProvider);
    try {
      final row = await repository.vendorLogoRow(profile.entityId);
      if (_disposed) return;
      state = state.copyWith(
        existingLogoUrl: () =>
            (row?['image_url'] as String?)?.trim().isEmpty == false
                ? row!['image_url'] as String
                : null,
      );
    } catch (_) {}
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void pickLogo(File file) => state = state.copyWith(pickedLogo: () => file);

  /// Uploads the picked logo (if any), then saves the profile through the one
  /// write path that keeps `partners` and `vendors` together. Returns null on
  /// success, or the error. Call once the form is valid. [readFields] is read
  /// once the logo is uploaded, as before.
  Future<Object?> save(BusinessInfoFields Function() readFields) async {
    final repository = ref.read(businessInfoRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    state = state.copyWith(saving: true);
    try {
      final userId = repository.currentUserId;
      if (userId == null) throw 'Not authenticated';
      final profile = ref.read(partnerProfileProvider).value;

      if (profile == null) throw 'Profil partenaire introuvable';

      // Le logo d'abord : il doit faire partie du meme enregistrement, sinon
      // une image envoyee et un nom enregistre se croisent et la fiche cliente
      // repart avec l'ancienne image.
      String? logoUrl;
      final pickedLogo = state.pickedLogo;
      if (pickedLogo != null && profile.entityId.isNotEmpty) {
        logoUrl = await repository.uploadLogo(profile.entityId, pickedLogo);
      }

      // UN seul chemin d'ecriture, celui qui tient `partners` et `vendors`
      // ensemble. Cet ecran ecrivait `partners` directement et ne recopiait
      // vers `vendors` que l'image : le nom, la description et l'adresse
      // n'atteignaient jamais le client.
      final fields = readFields();
      final ok = await authRepository.updatePartnerProfile(
            profile.copyWith(
              businessName: fields.name.trim(),
              address: fields.address.trim(),
              phone: fields.phone.trim(),
              bio: fields.bio.trim(),
              avatarUrl: logoUrl ?? profile.avatarUrl,
            ),
          );
      if (!ok) throw 'Enregistrement refuse';

      if (logoUrl != null && !_disposed) {
        state = state.copyWith(
          existingLogoUrl: () => logoUrl,
          pickedLogo: () => null,
        );
      }

      ref.invalidate(partnerProfileProvider);
      return null;
    } catch (e) {
      return e;
    } finally {
      if (!_disposed) state = state.copyWith(saving: false);
    }
  }
}
