import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../providers/menu_provider.dart';

/// How the partner chose the end of the deal. Kept separately from the
/// resulting DateTime so the matching chip stays highlighted.
enum HappyHourEnd { none, plus1h, plus2h, plus3h, tonight, custom }

/// One controller per happy hour screen on display. The argument carries a
/// key the screen creates for itself plus the deal's current end and
/// quantity, so the choices start where they were. Auto-disposed with the
/// screen, like the State it replaces.
final happyHourSetupControllerProvider = NotifierProvider.autoDispose.family<
    HappyHourSetupController,
    HappyHourSetupState,
    ({Object key, DateTime? currentEndTime, int? currentQuantity})>(
  HappyHourSetupController.new,
);

@immutable
class HappyHourSetupState {
  const HappyHourSetupState({
    this.endChoice = HappyHourEnd.none,
    this.endTime,
    this.limited = false,
    this.isLoading = false,
  });

  final HappyHourEnd endChoice;
  final DateTime? endTime;
  final bool limited;
  final bool isLoading;
}

/// Why a field is refused. The screen turns it into a translated text.
enum HappyHourFieldError { priceRequired, priceInvalid, priceTooHigh, quantityInvalid }

class HappyHourSetupController extends AutoDisposeFamilyNotifier<
    HappyHourSetupState,
    ({Object key, DateTime? currentEndTime, int? currentQuantity})> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  HappyHourSetupState build(
      ({Object key, DateTime? currentEndTime, int? currentQuantity}) arg) {
    ref.onDispose(() => _disposed = true);
    final end = arg.currentEndTime;
    final running = end != null && end.isAfter(DateTime.now());
    return HappyHourSetupState(
      limited: arg.currentQuantity != null,
      endTime: running ? end : null,
      endChoice: running ? HappyHourEnd.custom : HappyHourEnd.none,
    );
  }

  void _set({HappyHourEnd? endChoice, ValueGetter<DateTime?>? endTime, bool? limited, bool? isLoading}) {
    if (_disposed) return;
    state = HappyHourSetupState(
      endChoice: endChoice ?? state.endChoice,
      endTime: endTime != null ? endTime() : state.endTime,
      limited: limited ?? state.limited,
      isLoading: isLoading ?? state.isLoading,
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Picks the end of the deal. [customEnd] is the date picked for
  /// [HappyHourEnd.custom] (the screen shows the pickers).
  void chooseEnd(HappyHourEnd choice, {DateTime? customEnd}) {
    final now = DateTime.now();
    DateTime? end;
    switch (choice) {
      case HappyHourEnd.none:
        end = null;
      case HappyHourEnd.plus1h:
        end = now.add(const Duration(hours: 1));
      case HappyHourEnd.plus2h:
        end = now.add(const Duration(hours: 2));
      case HappyHourEnd.plus3h:
        end = now.add(const Duration(hours: 3));
      case HappyHourEnd.tonight:
        end = DateTime(now.year, now.month, now.day, 23, 59);
      case HappyHourEnd.custom:
        end = customEnd;
    }
    _set(endChoice: choice, endTime: () => end);
  }

  void setLimited(bool value) => _set(limited: value);

  /// Whether the chosen end is already behind us.
  bool get endIsInPast =>
      state.endTime != null && !state.endTime!.isAfter(DateTime.now());

  /// Puts the deal on [itemId]. [quantityText] counts only when the deal is
  /// limited. Returns whether it was saved. The price is sent rounded to the
  /// money step: the database would round it the same way anyway.
  Future<bool> activate({
    required String itemId,
    required double price,
    required String quantityText,
  }) async {
    _set(isLoading: true);
    final ok = await ref.read(menuRepositoryProvider).setHappyHour(
          itemId: itemId,
          discountPrice: roundMoney(price),
          endTime: state.endTime,
          quantity: state.limited ? int.parse(quantityText) : null,
        );
    _set(isLoading: false);
    return ok;
  }

  /// Ends the deal on [itemId]. Returns whether it worked.
  Future<bool> clear(String itemId) async {
    _set(isLoading: true);
    final ok = await ref.read(menuRepositoryProvider).clearHappyHour(itemId);
    _set(isLoading: false);
    return ok;
  }

  /// The menu reloads after a deal is set or cleared.
  void refreshMenu() => ref.invalidate(menuItemsProvider);

  // ── Rules ─────────────────────────────────────────────────────────────────

  /// A deal counts as running when it has a price and has not passed its
  /// end. A deal with no end date is running until it is cleared.
  static bool isActive({
    required double? currentDiscountPrice,
    required DateTime? currentEndTime,
  }) =>
      currentDiscountPrice != null &&
      (currentEndTime == null || currentEndTime.isAfter(DateTime.now()));

  static double? parsePrice(String text) =>
      double.tryParse(text.replaceAll(',', '.'));

  static int percentOff(double? price, double originalPrice) {
    final p = price;
    if (p == null || p <= 0 || p >= originalPrice) return 0;
    return ((originalPrice - p) / originalPrice * 100).round();
  }

  /// The price [percent] below [originalPrice], rounded to the money step
  /// (12.9 DT at -15 % is 10.965, shown and saved as 10.95).
  static double priceForPercent(double originalPrice, int percent) =>
      roundMoney(originalPrice * (100 - percent) / 100);

  /// Checks the price that will actually be saved, i.e. once rounded to the
  /// money step: 9.99 for a 10 DT item rounds to 10.00 and is no deal.
  static HappyHourFieldError? validatePrice(String? v, double originalPrice) {
    if (v == null || v.trim().isEmpty) return HappyHourFieldError.priceRequired;
    final d = parsePrice(v);
    if (d == null || d <= 0) return HappyHourFieldError.priceInvalid;
    final rounded = roundMoney(d);
    if (rounded <= 0) return HappyHourFieldError.priceInvalid;
    if (rounded >= originalPrice) return HappyHourFieldError.priceTooHigh;
    return null;
  }

  HappyHourFieldError? validateQuantity(String? v) {
    if (!state.limited) return null;
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1) return HappyHourFieldError.quantityInvalid;
    return null;
  }
}
