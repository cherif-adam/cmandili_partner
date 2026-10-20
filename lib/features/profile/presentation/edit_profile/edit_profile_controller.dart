import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';

/// One controller per edit-profile screen on display (the argument is a key
/// the screen creates for itself), auto-disposed with it like the State it
/// replaces.
final editProfileControllerProvider = NotifierProvider.autoDispose
    .family<EditProfileController, EditProfileState, Object>(
        EditProfileController.new);

/// What the user typed, untrimmed.
typedef EditProfileFields = ({
  String name,
  String address,
  String phone,
  String bio,
});

/// How saving ended.
enum EditProfileOutcome { updated, failed, noProfile }

@immutable
class EditProfileState {
  const EditProfileState({this.imageFile, this.isLoading = false});

  /// The new photo picked from the gallery, not uploaded yet.
  final File? imageFile;
  final bool isLoading;
}

class EditProfileController
    extends AutoDisposeFamilyNotifier<EditProfileState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  EditProfileState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const EditProfileState();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// The values the fields open with: the shop's profile first, the account
  /// second.
  ({String name, String email, String phone, String bio, String address})
      initialValues() {
    final user = ref.read(authRepositoryProvider).currentUser;
    final profile = ref.read(partnerProfileProvider).value;
    return (
      name: profile?.businessName ?? user?.displayName ?? '',
      email: user?.email ?? '',
      phone: profile?.phone ?? '',
      bio: profile?.bio ?? '',
      address: profile?.address ?? '',
    );
  }

  /// The account's own photo, shown until a new one is picked. Read at each
  /// build, as before.
  String? get photoUrl => ref.read(authRepositoryProvider).currentUser?.photoURL;

  // ── User actions ──────────────────────────────────────────────────────────

  void setImage(File file) =>
      state = EditProfileState(imageFile: file, isLoading: state.isLoading);

  /// Uploads the new photo (if any), then saves the profile. Call once the
  /// form is valid.
  ///
  /// [onAvatarFailed] is called right after a failed upload, before the
  /// profile is saved (the screen warns at that moment, as before).
  /// [readFields] is read once the upload is done, as before.
  Future<EditProfileOutcome> save({
    required VoidCallback onAvatarFailed,
    required EditProfileFields Function() readFields,
  }) async {
    _setLoading(true);
    final repo = ref.read(authRepositoryProvider);
    final profile = ref.read(partnerProfileProvider).value;

    String? newAvatarUrl;
    bool uploadSuccess = true;
    final imageFile = state.imageFile;
    if (imageFile != null) {
      final path = '${profile?.userId ?? 'avatar'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      newAvatarUrl = await repo.uploadAvatar(path, imageFile);
      uploadSuccess = newAvatarUrl != null;
    }

    if (!uploadSuccess) onAvatarFailed();

    // La recopie vers `vendors` vivait ici, et ne portait que l'image : le
    // nom et la description restaient dans `partners`, invisibles du client.
    // Elle est maintenant dans updatePartnerProfile, avec les autres champs,
    // pour qu'un seul endroit decide de ce que le client voit.

    if (profile == null) {
      _setLoading(false);
      return EditProfileOutcome.noProfile;
    }

    final fields = readFields();
    final updatedProfile = profile.copyWith(
      businessName: fields.name.trim(),
      address: fields.address.trim(),
      phone: fields.phone.trim(),
      bio: fields.bio.trim(),
      avatarUrl: newAvatarUrl ?? profile.avatarUrl,
    );

    final updateSuccess = await repo.updatePartnerProfile(updatedProfile);
    _setLoading(false);
    return updateSuccess ? EditProfileOutcome.updated : EditProfileOutcome.failed;
  }

  /// After a successful save: everything showing the profile reloads it.
  void refreshProfile() => ref.invalidate(partnerProfileProvider);

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    if (_disposed) return;
    state = EditProfileState(imageFile: state.imageFile, isLoading: value);
  }
}
