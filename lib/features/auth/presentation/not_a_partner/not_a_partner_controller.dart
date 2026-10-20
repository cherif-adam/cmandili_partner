import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// The "not a partner account" screen's one action. No state of its own;
/// kept alive by the screen watching it.
final notAPartnerControllerProvider =
    NotifierProvider.autoDispose<NotAPartnerController, void>(
        NotAPartnerController.new);

class NotAPartnerController extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  /// Signs out: main.dart then shows the sign-in screen.
  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}
