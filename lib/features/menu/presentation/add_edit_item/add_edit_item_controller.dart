import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/data/models/partner_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/models/food_item.dart';
import '../../data/models/grocery_category.dart';
import '../../data/models/grocery_item.dart';
import '../../data/models/item_variant.dart';
import '../../data/models/vendor_item.dart';
import '../../providers/menu_provider.dart';

/// What the screen hands over: the item being edited (none when adding)
/// and the partner's type, plus a key the screen creates for itself so each
/// screen on display has its own controller.
typedef AddEditItemArgs = ({
  Object key,
  String partnerType,
  FoodItem? food,
  GroceryItem? grocery,
  VendorItem? vendor,
});

/// One controller per add / edit screen on display, auto-disposed with it,
/// like the State it replaces. The text fields and the variant rows stay
/// with the screen; everything else the form holds is here.
final addEditItemControllerProvider = NotifierProvider.autoDispose
    .family<AddEditItemController, AddEditItemState, AddEditItemArgs>(
  AddEditItemController.new,
);

@immutable
class AddEditItemState {
  const AddEditItemState({
    this.isAvailable = true,
    this.isVegetarian = false,
    this.isSpicy = false,
    this.isOrganic = false,
    this.groceryCategory = GroceryCategory.vegetables,
    this.isHappyHour = false,
    this.happyHourStart,
    this.happyHourEnd,
    this.imageFile,
    this.categoryIcon,
    this.customCategories = const [],
    this.isLoading = false,
  });

  final bool isAvailable;
  final bool isVegetarian;
  final bool isSpicy;
  final bool isOrganic;
  final GroceryCategory groceryCategory;
  final bool isHappyHour;
  final TimeOfDay? happyHourStart;
  final TimeOfDay? happyHourEnd;

  /// The photo picked on the phone, sent on save.
  final File? imageFile;

  /// The emoji of the category picked in the sheet (none for a category the
  /// item already had).
  final String? categoryIcon;

  /// Categories the partner created on this screen.
  final List<Map<String, String>> customCategories;
  final bool isLoading;
}

/// The text fields, read when the save needs them.
typedef ItemFields = ({
  String name,
  String description,
  String price,
  String category,
  String imageUrl,
  String prepTime,
  String unit,
  String happyHourPrice,
});

/// One variant row as typed.
typedef VariantRow = ({String id, String name, String price, bool isAvailable});

/// Why the form cannot be saved yet. The screen turns it into a message.
enum ItemSaveProblem {
  categoryMissing,
  happyHourPriceInvalid,
  happyHourPriceTooHigh,
  happyHourTimesMissing,
}

enum ItemPriceError { missing, notANumber, notPositive }

enum ItemSaveOutcome { saved, failed, imageUploadFailed }

class AddEditItemController
    extends AutoDisposeFamilyNotifier<AddEditItemState, AddEditItemArgs> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;
  final _picker = ImagePicker();

  @override
  AddEditItemState build(AddEditItemArgs arg) {
    ref.onDispose(() => _disposed = true);
    final fi = arg.food;
    final gi = arg.grocery;
    final vi = arg.vendor;
    return AddEditItemState(
      isAvailable: fi?.isAvailable ?? gi?.isAvailable ?? vi?.isAvailable ?? true,
      isVegetarian: fi?.isVegetarian ?? false,
      isSpicy: fi?.isSpicy ?? false,
      isOrganic: gi?.isOrganic ?? false,
      isHappyHour: fi?.isHappyHour ?? false,
      happyHourStart: parseTime(fi?.happyHourStart),
      happyHourEnd: parseTime(fi?.happyHourEnd),
      groceryCategory: gi?.category ?? GroceryCategory.vegetables,
    );
  }

  void _set({
    bool? isAvailable,
    bool? isVegetarian,
    bool? isSpicy,
    bool? isOrganic,
    GroceryCategory? groceryCategory,
    bool? isHappyHour,
    ValueGetter<TimeOfDay?>? happyHourStart,
    ValueGetter<TimeOfDay?>? happyHourEnd,
    ValueGetter<File?>? imageFile,
    ValueGetter<String?>? categoryIcon,
    List<Map<String, String>>? customCategories,
    bool? isLoading,
  }) {
    if (_disposed) return;
    state = AddEditItemState(
      isAvailable: isAvailable ?? state.isAvailable,
      isVegetarian: isVegetarian ?? state.isVegetarian,
      isSpicy: isSpicy ?? state.isSpicy,
      isOrganic: isOrganic ?? state.isOrganic,
      groceryCategory: groceryCategory ?? state.groceryCategory,
      isHappyHour: isHappyHour ?? state.isHappyHour,
      happyHourStart:
          happyHourStart != null ? happyHourStart() : state.happyHourStart,
      happyHourEnd: happyHourEnd != null ? happyHourEnd() : state.happyHourEnd,
      imageFile: imageFile != null ? imageFile() : state.imageFile,
      categoryIcon: categoryIcon != null ? categoryIcon() : state.categoryIcon,
      customCategories: customCategories ?? state.customCategories,
      isLoading: isLoading ?? state.isLoading,
    );
  }

  bool get isRestaurant => arg.partnerType == 'restaurant';

  /// Generic vendor categories. They share the restaurant's free-text category
  /// field but none of its food-specific extras, and they have no variants or
  /// happy-hour tables behind them.
  bool get isVendor => isGenericVendorType(arg.partnerType);

  bool get isEditing => arg.food != null || arg.grocery != null || arg.vendor != null;

  // ── User actions ──────────────────────────────────────────────────────────

  void setAvailable(bool value) => _set(isAvailable: value);
  void setVegetarian(bool value) => _set(isVegetarian: value);
  void setSpicy(bool value) => _set(isSpicy: value);
  void setOrganic(bool value) => _set(isOrganic: value);
  void setGroceryCategory(GroceryCategory value) => _set(groceryCategory: value);
  void setHappyHour(bool value) => _set(isHappyHour: value);
  void setHappyHourStart(TimeOfDay value) => _set(happyHourStart: () => value);
  void setHappyHourEnd(TimeOfDay value) => _set(happyHourEnd: () => value);

  /// The category picked in the sheet; the screen puts its name in the field.
  void chooseCategoryIcon(String? icon) => _set(categoryIcon: () => icon);

  /// A category the partner just created, which becomes the item's.
  void addCustomCategory(String name, String icon) => _set(
        customCategories: [
          ...state.customCategories,
          {'name': name, 'icon': icon},
        ],
        categoryIcon: () => icon,
      );

  Future<void> pickImage() async {
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      _set(imageFile: () => File(pickedFile.path));
    }
  }

  /// The item's variants when editing (vendor_items has no variants table
  /// behind it), none otherwise.
  Future<List<ItemVariant>?> loadVariants() async {
    if (!isEditing || isVendor) return null;
    final id = arg.food?.id ?? arg.grocery?.id;
    if (id == null) return null;
    final repo = ref.read(menuRepositoryProvider);
    return repo.getVariants(itemId: id, isGrocery: !isRestaurant);
  }

  /// The checks made before anything is sent, in their original order.
  ItemSaveProblem? checkBeforeSave({
    required String category,
    required String price,
    required String happyHourPrice,
  }) {
    if (isRestaurant && category.trim().isEmpty) {
      return ItemSaveProblem.categoryMissing;
    }
    if (state.isHappyHour) {
      final hpText = happyHourPrice.trim();
      final basePrice = double.tryParse(price) ?? 0.0;
      final hpPrice = double.tryParse(hpText);
      if (hpText.isEmpty || hpPrice == null || hpPrice <= 0) {
        return ItemSaveProblem.happyHourPriceInvalid;
      }
      if (hpPrice >= basePrice) return ItemSaveProblem.happyHourPriceTooHigh;
      if (state.happyHourStart == null || state.happyHourEnd == null) {
        return ItemSaveProblem.happyHourTimesMissing;
      }
    }
    return null;
  }

  /// Sends the photo (if one was picked), saves the item in the table its
  /// partner type uses, then replaces its variants. [readFields] and
  /// [readVariants] are called when the values are needed, after the
  /// earlier steps; [onImageUploaded] gets the new photo's address first.
  Future<ItemSaveOutcome> save({
    required ItemFields Function() readFields,
    required List<VariantRow> Function() readVariants,
    required void Function(String url) onImageUploaded,
  }) async {
    _set(isLoading: true);
    final repo = ref.read(menuRepositoryProvider);
    final profile = await ref.read(partnerProfileProvider.future);
    bool ok = false;

    // Upload Image if selected.
    //
    // A failed upload used to fall through with the OLD url still in the
    // controller, so the item saved "successfully" with its previous picture
    // and the partner had no way to know the new one never left the phone.
    final imageFile = state.imageFile;
    if (imageFile != null) {
      final ext = imageFile.path.split('.').last;
      String path = '${const Uuid().v4()}.$ext';
      final url = await repo.uploadItemImage(path, imageFile);
      if (url == null) {
        _set(isLoading: false);
        return ItemSaveOutcome.imageUploadFailed;
      }
      onImageUploaded(url);
    }

    final f = readFields();
    String? savedItemId;
    if (isRestaurant) {
      final item = FoodItem(
        id: arg.food?.id ?? const Uuid().v4(),
        restaurantId: profile?.entityId ?? '',
        name: f.name.trim(),
        description: f.description.trim(),
        imageUrl: f.imageUrl.trim(),
        price: double.parse(f.price),
        category: f.category.trim(),
        isAvailable: state.isAvailable,
        preparationTime: int.tryParse(f.prepTime) ?? 15,
        isVegetarian: state.isVegetarian,
        isSpicy: state.isSpicy,
        isHappyHour: state.isHappyHour,
        happyHourPrice:
            state.isHappyHour ? double.tryParse(f.happyHourPrice) : null,
        happyHourStart: state.isHappyHour ? _formatTime(state.happyHourStart) : null,
        happyHourEnd: state.isHappyHour ? _formatTime(state.happyHourEnd) : null,
      );
      if (isEditing) {
        ok = await repo.updateFoodItem(item);
        savedItemId = item.id;
      } else {
        final id = await repo.addFoodItem(item, profile?.entityId ?? '');
        ok = id != null;
        savedItemId = id;
      }
    } else if (isVendor) {
      // Straight at `vendor_items`. The grocery branch below writes through a
      // supermarket-filtered view, so a florist saving there produced a row its
      // own catalogue query immediately filtered out.
      final vendorId = profile?.entityId ?? '';
      final name = f.name.trim();
      final price = double.parse(f.price);
      final description = f.description.trim();
      final imageUrl = f.imageUrl.trim();
      final category = f.category.trim();
      final unit = f.unit.trim();

      if (isEditing) {
        final id = arg.vendor!.id;
        ok = await repo.updateVendorItem(id, {
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'price': price,
          'category': category,
          'unit': unit.isEmpty ? null : unit,
          'is_available': state.isAvailable,
        });
        savedItemId = id;
      } else {
        final id = await repo.addVendorItem(
          vendorId: vendorId,
          name: name,
          price: price,
          description: description,
          imageUrl: imageUrl,
          category: category.isEmpty ? null : category,
          unit: unit.isEmpty ? null : unit,
          isAvailable: state.isAvailable,
        );
        ok = id != null;
        savedItemId = id;
      }
    } else {
      final item = GroceryItem(
        id: arg.grocery?.id ?? const Uuid().v4(),
        supermarketId: profile?.entityId ?? '',
        name: f.name.trim(),
        description: f.description.trim(),
        imageUrl: f.imageUrl.trim(),
        price: double.parse(f.price),
        category: state.groceryCategory,
        unit: f.unit.trim(),
        isOrganic: state.isOrganic,
        isAvailable: state.isAvailable,
      );
      if (isEditing) {
        ok = await repo.updateGroceryItem(item);
        savedItemId = item.id;
      } else {
        final id = await repo.addGroceryItem(item, profile?.entityId ?? '');
        ok = id != null;
        savedItemId = id;
      }
    }

    // After the item itself is saved, replace its variant list. Skips when
    // the item save failed — variants without an item are orphans.
    if (ok && savedItemId != null && !isVendor) {
      final rows = readVariants();
      final cleaned = <ItemVariant>[];
      for (var i = 0; i < rows.length; i++) {
        final d = rows[i];
        final name = d.name.trim();
        final priceStr = d.price.trim();
        if (name.isEmpty || priceStr.isEmpty) continue;
        final price = double.tryParse(priceStr);
        if (price == null) continue;
        cleaned.add(ItemVariant(
          id: d.id,
          name: name,
          price: price,
          isAvailable: d.isAvailable,
          sortOrder: i,
        ));
      }
      await repo.replaceVariants(
        itemId: savedItemId,
        isGrocery: !isRestaurant,
        variants: cleaned,
      );
    }

    _set(isLoading: false);
    return ok ? ItemSaveOutcome.saved : ItemSaveOutcome.failed;
  }

  /// The menu reloads after a save.
  void refreshMenu() => ref.invalidate(menuItemsProvider);

  // ── Categories ────────────────────────────────────────────────────────────

  /// Default restaurant categories with emojis.
  static const List<Map<String, String>> defaultRestaurantCategories = [
    {'name': 'Starters', 'icon': '🥗'},
    {'name': 'Mains', 'icon': '🍽️'},
    {'name': 'Pizza', 'icon': '🍕'},
    {'name': 'Burgers', 'icon': '🍔'},
    {'name': 'Pasta', 'icon': '🍝'},
    {'name': 'Grills', 'icon': '🥩'},
    {'name': 'Seafood', 'icon': '🦐'},
    {'name': 'Salads', 'icon': '🥬'},
    {'name': 'Soups', 'icon': '🍲'},
    {'name': 'Sandwiches', 'icon': '🥪'},
    {'name': 'Desserts', 'icon': '🍰'},
    {'name': 'Drinks', 'icon': '🥤'},
    {'name': 'Breakfast', 'icon': '🍳'},
    {'name': 'Kids Menu', 'icon': '🧒'},
  ];

  /// The sheet's choices: default + custom + any unique ones from existing
  /// items.
  List<Map<String, String>> categoryChoices() {
    final itemsAsync = ref.read(menuItemsProvider);
    List<Map<String, String>> allCategories = [
      ...defaultRestaurantCategories,
      ...state.customCategories,
    ];

    if (itemsAsync is AsyncData) {
      final items = itemsAsync.value ?? [];
      final existingNames = items
          .whereType<FoodItem>()
          .map((e) => e.category)
          .where((c) => c.isNotEmpty)
          .toSet();
      // Add any existing-in-DB categories that aren't in our list already
      for (final name in existingNames) {
        if (!allCategories.any((c) => c['name'] == name)) {
          allCategories.add({'name': name, 'icon': '📁'});
        }
      }
    }
    return allCategories;
  }

  // ── Rules ─────────────────────────────────────────────────────────────────

  static ItemPriceError? validatePrice(String? v) {
    if (v == null || v.isEmpty) return ItemPriceError.missing;
    final parsed = double.tryParse(v);
    if (parsed == null) return ItemPriceError.notANumber;
    if (parsed <= 0) return ItemPriceError.notPositive;
    return null;
  }

  static TimeOfDay? parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    return null;
  }

  static String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }
}
