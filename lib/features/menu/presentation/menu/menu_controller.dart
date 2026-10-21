import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/models/food_item.dart';
import '../../data/models/grocery_item.dart';
import '../../data/models/vendor_item.dart';
import '../../providers/menu_provider.dart';
import '../../providers/menu_scanner_provider.dart';

/// The menu tab's logic. Its state is the search text (lower-case); the
/// items, the chosen category and the scanner keep their own providers.
/// Kept alive by the screen watching it. (Not "MenuController": Flutter's
/// material library already has one.)
final menuControllerProvider =
    NotifierProvider.autoDispose<PartnerMenuController, String>(
        PartnerMenuController.new);

class PartnerMenuController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  // ── User actions ──────────────────────────────────────────────────────────

  void setQuery(String value) => state = value.toLowerCase();

  void clearQuery() => state = '';

  void selectCategory(String? value) =>
      ref.read(selectedCategoryProvider.notifier).state = value;

  void scanMenu(ImageSource source) =>
      ref.read(menuScannerProvider.notifier).scanPhysicalMenu(source: source);

  /// The menu reloads (after an edit, a deal, a deletion).
  void refreshMenu() => ref.invalidate(menuItemsProvider);

  /// Turns an item on or off. Returns whether it was saved.
  Future<bool> setAvailability(
    String itemId,
    bool value, {
    required bool isGrocery,
    required bool isVendor,
  }) async {
    final repo = ref.read(menuRepositoryProvider);
    // updateItemAvailability only knows the two legacy views; vendor items
    // live in their own table.
    return isVendor
        ? await repo.updateVendorItem(itemId, {'is_available': value})
        : await repo.updateItemAvailability(
            itemId,
            value,
            isGrocery: isGrocery,
          );
  }

  /// Deletes an item from the table it lives in, then reloads the menu.
  Future<void> deleteItem(
    String itemId, {
    required bool isRestaurant,
    required bool isVendor,
  }) async {
    final repo = ref.read(menuRepositoryProvider);
    if (isRestaurant) {
      await repo.deleteFoodItem(itemId);
    } else if (isVendor) {
      await repo.deleteVendorItem(itemId);
    } else {
      await repo.deleteGroceryItem(itemId);
    }
    ref.invalidate(menuItemsProvider);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// What the category deal sheet works from: every item (not the list
  /// filtered by the chosen category) and the shop's id.
  ({List<dynamic> items, String? vendorId}) categoryPromoSource() => (
        items: ref.read(menuItemsProvider).valueOrNull ?? const [],
        vendorId: ref.read(partnerProfileProvider).valueOrNull?.entityId,
      );

  /// [items] whose name contains the search text.
  List<dynamic> filterBySearch(List<dynamic> items) {
    return state.isEmpty
        ? items
        : items.where((item) {
            final name = switch (item) {
              FoodItem i => i.name.toLowerCase(),
              GroceryItem i => i.name.toLowerCase(),
              VendorItem i => i.name.toLowerCase(),
              _ => '',
            };
            return name.contains(state);
          }).toList();
  }

  static int countInCategory(List<dynamic> items, String category) {
    return items.where((item) {
      if (item is FoodItem) return item.category == category;
      if (item is GroceryItem) {
        return item.category.toString().split('.').last == category;
      }
      if (item is VendorItem) return item.category == category;
      return false;
    }).length;
  }

  static List<String> extractCategories(List<dynamic> items) {
    final cats = <String>{};
    for (final item in items) {
      if (item is FoodItem && item.category.isNotEmpty) cats.add(item.category);
      if (item is GroceryItem) {
        cats.add(item.category.toString().split('.').last);
      }
      if (item is VendorItem && item.category.isNotEmpty) cats.add(item.category);
    }
    return cats.toList()..sort();
  }
}
