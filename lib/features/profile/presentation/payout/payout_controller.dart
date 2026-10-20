import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/partner_wallet_provider.dart';

/// One controller per payout screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final payoutControllerProvider = NotifierProvider.autoDispose
    .family<PayoutController, PayoutState, Object>(PayoutController.new);

/// The bank details, as typed or as saved.
typedef PayoutFields = ({String bankName, String iban, String accountHolder});

@immutable
class PayoutState {
  const PayoutState({this.loading = true, this.saving = false});

  final bool loading;
  final bool saving;
}

class PayoutController extends AutoDisposeFamilyNotifier<PayoutState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  PayoutState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    // Signed out: nothing to load, so the form shows from the first frame
    // (the screen used to switch the spinner off inside initState).
    return PayoutState(
      loading: ref.read(payoutRepositoryProvider).currentUserId != null,
    );
  }

  void _set({bool? loading, bool? saving}) {
    if (_disposed) return;
    state = PayoutState(
      loading: loading ?? state.loading,
      saving: saving ?? state.saving,
    );
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// The saved bank details (null fields stay empty), or null when there are
  /// none or they could not be read. Ends the loading state either way.
  Future<PayoutFields?> load() async {
    final repository = ref.read(payoutRepositoryProvider);
    final userId = repository.currentUserId;
    if (userId == null) return null; // loading is already false: see build()
    PayoutFields? fields;
    try {
      final row = await repository.payoutInfo(userId);
      if (row != null) {
        fields = (
          bankName: row['bank_name'] as String? ?? '',
          iban: row['iban'] as String? ?? '',
          accountHolder: row['account_holder'] as String? ?? '',
        );
      }
    } catch (_) {}
    _set(loading: false);
    return fields;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Saves the bank details (trimmed). Returns null on success, or the
  /// error. Call once the form is valid.
  Future<Object?> save(PayoutFields fields) async {
    final repository = ref.read(payoutRepositoryProvider);
    _set(saving: true);
    try {
      final userId = repository.currentUserId;
      if (userId == null) throw 'Not authenticated';
      await repository.savePayoutInfo(
        userId: userId,
        bankName: fields.bankName.trim(),
        iban: fields.iban.trim(),
        accountHolder: fields.accountHolder.trim(),
      );
      return null;
    } catch (e) {
      return e;
    } finally {
      _set(saving: false);
    }
  }
}
