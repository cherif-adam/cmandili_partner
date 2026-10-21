import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/menu_provider.dart';

/// One controller per promotion screen on display. The argument carries a key
/// the screen creates for itself plus the promotion's current dates, so the
/// dates start where they were. Auto-disposed with the screen, like the
/// State it replaces.
final promoSetupControllerProvider = NotifierProvider.autoDispose.family<
    PromoSetupController,
    PromoSetupState,
    ({Object key, DateTime? start, DateTime? end})>(PromoSetupController.new);

@immutable
class PromoSetupState {
  const PromoSetupState({this.startTime, this.endTime, this.isLoading = false});

  /// Null: "now, as soon as it is saved".
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isLoading;

  /// [startTime] and [endTime] are getters so they can be set back to null.
  PromoSetupState copyWith({
    ValueGetter<DateTime?>? startTime,
    ValueGetter<DateTime?>? endTime,
    bool? isLoading,
  }) =>
      PromoSetupState(
        startTime: startTime != null ? startTime() : this.startTime,
        endTime: endTime != null ? endTime() : this.endTime,
        isLoading: isLoading ?? this.isLoading,
      );

  /// Debut effectif : ce que le commercant a choisi, ou maintenant.
  DateTime get effectiveStart => startTime ?? DateTime.now();
}

/// Why the percentage is refused. The screen turns it into a sentence.
enum PromoPercentError { missing, belowOne, aboveMax }

/// Why the dates are refused. The screen turns it into a sentence.
enum PromoDateError { missingEnd, startInPast, endBeforeStart, endPassed }

class PromoSetupController extends AutoDisposeFamilyNotifier<PromoSetupState,
    ({Object key, DateTime? start, DateTime? end})> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  PromoSetupState build(({Object key, DateTime? start, DateTime? end}) arg) {
    ref.onDispose(() => _disposed = true);
    return PromoSetupState(startTime: arg.start, endTime: arg.end);
  }

  void _setLoading(bool value) {
    if (!_disposed) state = state.copyWith(isLoading: value);
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void setStart(DateTime? value) => state = state.copyWith(startTime: () => value);

  void setEnd(DateTime? value) => state = state.copyWith(endTime: () => value);

  /// Puts [percent] on one item, or on a whole category when [categoryName]
  /// is set. Returns how many items were updated (an item counts 1, 0 when
  /// refused).
  Future<int> save({
    required double percent,
    required String? itemId,
    required double originalPrice,
    required String? categoryName,
    required String? vendorId,
  }) async {
    _setLoading(true);
    final repo = ref.read(menuRepositoryProvider);
    final int count;
    if (categoryName != null) {
      count = await repo.setPercentPromoForCategory(
        vendorId: vendorId!,
        category: categoryName,
        percent: percent,
        startTime: state.startTime,
        endTime: state.endTime,
      );
    } else {
      final ok = await repo.setPercentPromo(
        itemId: itemId!,
        originalPrice: originalPrice,
        percent: percent,
        startTime: state.startTime,
        endTime: state.endTime,
      );
      count = ok ? 1 : 0;
    }
    // Like before, an error leaves the spinner on: nothing catches it here.
    _setLoading(false);
    return count;
  }

  /// Ce qui a été posé en une action doit pouvoir être retiré en une action :
  /// un commerçant qui a bradé quarante références ne va pas les rouvrir une
  /// par une. Returns how many items went back to their normal price (an
  /// item counts 1, 0 when refused).
  Future<int> stop({required String? itemId, required String? categoryName, required String? vendorId}) async {
    _setLoading(true);
    final repo = ref.read(menuRepositoryProvider);
    final int count;
    if (categoryName != null) {
      count = await repo.clearPromoForCategory(
        vendorId: vendorId!,
        category: categoryName,
      );
    } else {
      final ok = await repo.clearPromo(itemId!);
      count = ok ? 1 : 0;
    }
    _setLoading(false);
    return count;
  }

  /// The menu reloads after a promotion is set or stopped.
  void refreshMenu() => ref.invalidate(menuItemsProvider);

  // ── Rules ─────────────────────────────────────────────────────────────────

  /// Il y a une promotion a arreter des qu'un taux ou un prix est pose et que
  /// la fin n'est pas passee.
  ///
  /// Le taux compte autant que le prix : une promotion PROGRAMMEE n'a pas
  /// encore de prix -- il n'est materialise qu'a l'instant du debut -- et le
  /// commercant doit pouvoir l'annuler avant qu'elle ne parte. C'est meme le
  /// seul moment ou l'annuler ne coute rien.
  static bool hasPromo({
    required double? currentDiscountPrice,
    required double? currentPercent,
    required DateTime? currentEndTime,
  }) =>
      (currentDiscountPrice != null || currentPercent != null) &&
      (currentEndTime == null || currentEndTime.isAfter(DateTime.now()));

  static double? parsePercent(String text) =>
      double.tryParse(text.replaceAll(',', '.'));

  static PromoPercentError? validatePercent(String? raw, double maxPercent) {
    final v = double.tryParse((raw ?? '').replaceAll(',', '.'));
    if (v == null) return PromoPercentError.missing;
    if (v < 1) return PromoPercentError.belowOne;
    if (v > maxPercent) return PromoPercentError.aboveMax;
    return null;
  }

  /// Les controles que le formulaire ne peut pas faire seul, parce qu'ils
  /// portent sur la coherence entre deux champs. Chacun a son propre message :
  /// "date invalide" n'apprend rien au commercant.
  PromoDateError? validateDates() {
    final now = DateTime.now();
    final startTime = state.startTime;
    final endTime = state.endTime;
    if (endTime == null) {
      return PromoDateError.missingEnd;
    }
    // Une minute de tolerance : le temps de remplir le formulaire, un debut
    // choisi "maintenant" serait sinon deja dans le passe au moment du clic.
    if (startTime != null &&
        startTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return PromoDateError.startInPast;
    }
    if (!endTime.isAfter(state.effectiveStart)) {
      return PromoDateError.endBeforeStart;
    }
    if (!endTime.isAfter(now)) {
      return PromoDateError.endPassed;
    }
    return null;
  }
}
