import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/food_item.dart';
import '../../data/models/grocery_item.dart';
import '../../data/models/grocery_category.dart';
import '../../data/models/vendor_item.dart';
import 'add_edit_item_controller.dart';
import 'widgets/category_picker_sheet.dart';
import 'widgets/happy_hour_section.dart';
import 'widgets/item_form_fields.dart';
import 'widgets/item_image_picker.dart';
import 'widgets/new_category_dialog.dart';
import 'widgets/variants_editor.dart';

/// Adds an item, or edits the one given: basic information and photo,
/// category, variants and Happy Hour (not for the generic vendor
/// categories), details and switches, then the save button.
class AddEditItemScreen extends ConsumerStatefulWidget {
  final FoodItem? existingFoodItem;
  final GroceryItem? existingGroceryItem;

  /// Set for the generic categories (bakery, flowers, pets, gifts,
  /// electronics), whose catalogue lives in `vendor_items`.
  final VendorItem? existingVendorItem;
  final String partnerType;

  const AddEditItemScreen({
    super.key,
    this.existingFoodItem,
    this.existingGroceryItem,
    this.existingVendorItem,
    required this.partnerType,
  });

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _provider = addEditItemControllerProvider((
    key: Object(),
    partnerType: widget.partnerType,
    food: widget.existingFoodItem,
    grocery: widget.existingGroceryItem,
    vendor: widget.existingVendorItem,
  ));

  AddEditItemController get _controller => ref.read(_provider.notifier);

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _imageUrlController;
  late TextEditingController _prepTimeController;
  late TextEditingController _unitController;
  late TextEditingController _happyHourPriceController;

  // Variants editor state. Each row is held as a tuple of controllers + the
  // original ItemVariant id so we can preserve unchanged rows on save. The id
  // is empty for newly-added rows; `replaceVariants` reissues fresh ids on
  // insert anyway, so the local id only matters for keying the ListView.
  final List<VariantDraft> _variants = [];

  @override
  void initState() {
    super.initState();
    final fi = widget.existingFoodItem;
    final gi = widget.existingGroceryItem;
    final vi = widget.existingVendorItem;

    _nameController =
        TextEditingController(text: fi?.name ?? gi?.name ?? vi?.name ?? '');
    _descController = TextEditingController(
        text: fi?.description ?? gi?.description ?? vi?.description ?? '');
    _priceController = TextEditingController(
        text: (fi?.price ?? gi?.price ?? vi?.price)?.toStringAsFixed(2) ?? '');
    _categoryController =
        TextEditingController(text: fi?.category ?? vi?.category ?? '');
    _imageUrlController = TextEditingController(
        text: fi?.imageUrl ?? gi?.imageUrl ?? vi?.imageUrl ?? '');
    _prepTimeController = TextEditingController(
        text: fi?.preparationTime.toString() ?? '15');
    _unitController =
        TextEditingController(text: gi?.unit ?? vi?.unit ?? 'piece');
    _happyHourPriceController = TextEditingController(
        text: fi?.happyHourPrice?.toStringAsFixed(2) ?? '');

    _loadVariants();
  }

  Future<void> _loadVariants() async {
    final list = await _controller.loadVariants();
    if (list == null) return;
    if (!mounted) return;
    setState(() {
      _variants
        ..clear()
        ..addAll(list.map((v) => VariantDraft(
              id: v.id,
              name: v.name,
              price: v.price,
              isAvailable: v.isAvailable,
            )));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _unitController.dispose();
    _happyHourPriceController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  ItemFields _readFields() => (
        name: _nameController.text,
        description: _descController.text,
        price: _priceController.text,
        category: _categoryController.text,
        imageUrl: _imageUrlController.text,
        prepTime: _prepTimeController.text,
        unit: _unitController.text,
        happyHourPrice: _happyHourPriceController.text,
      );

  List<VariantRow> _readVariants() => [
        for (final d in _variants)
          (
            id: d.id,
            name: d.nameCtrl.text,
            price: d.priceCtrl.text,
            isAvailable: d.isAvailable,
          ),
      ];

  void _showError(String text, {bool floating = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: floating ? SnackBarBehavior.floating : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final problem = _controller.checkBeforeSave(
      category: _categoryController.text,
      price: _priceController.text,
      happyHourPrice: _happyHourPriceController.text,
    );
    if (problem != null) {
      _showError(switch (problem) {
        ItemSaveProblem.categoryMissing =>
          AppLocalizations.of(context)!.selectCategory,
        ItemSaveProblem.happyHourPriceInvalid =>
          'Veuillez entrer un prix valide pour l\'Happy Hour',
        ItemSaveProblem.happyHourPriceTooHigh =>
          'Le prix Happy Hour doit être inférieur au prix normal',
        ItemSaveProblem.happyHourTimesMissing =>
          'Veuillez sélectionner l\'heure de début et de fin',
      });
      return;
    }

    final outcome = await _controller.save(
      readFields: _readFields,
      readVariants: _readVariants,
      onImageUploaded: (url) => _imageUrlController.text = url,
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    switch (outcome) {
      case ItemSaveOutcome.imageUploadFailed:
        _showError(
            "Impossible d'envoyer l'image. Vérifiez votre connexion et réessayez.",
            floating: true);
      case ItemSaveOutcome.saved:
        _controller.refreshMenu();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.isEditing ? l.itemUpdated : l.itemAdded),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ItemSaveOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.failedToSave),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showCategorySheet() {
    showCategoryPickerSheet(
      context: context,
      categories: _controller.categoryChoices(),
      selected: () => _categoryController.text,
      onPick: (cat) {
        _categoryController.text = cat['name']!;
        _controller.chooseCategoryIcon(cat['icon']);
      },
      onAddNew: () => showNewCategoryDialog(
        context: context,
        onCreate: (name, emoji) {
          _categoryController.text = name;
          _controller.addCustomCategory(name, emoji);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_provider);
    final c = _controller;
    final isRestaurant = c.isRestaurant;
    final isVendor = c.isVendor;
    final isEditing = c.isEditing;
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        // No 'Add '/'Edit ' prefix: the localized strings already carry the
        // verb, so prefixing produced "Add Add Dish" / "Edit Ajouter un
        // produit". A prefix also cannot work across locales -- Arabic and
        // French put the verb in a different place than English.
        title: Text(isEditing
            ? (isRestaurant ? l.editDish : l.editProduct)
            : (isRestaurant ? l.addDish : l.addProduct)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          _SaveAction(isLoading: s.isLoading, onSave: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        // One list entry per form part, as before: the list builds (and the
        // form validates) only the parts near the screen.
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ItemSectionLabel('Basic Information'),
            const SizedBox(height: 10),
            ItemTextField(_nameController, 'Name',
                Icons.label_outline_rounded, required: true),
            const SizedBox(height: 14),
            ItemTextField(_descController, 'Description',
                Icons.description_outlined,
                maxLines: 3, required: true),
            const SizedBox(height: 14),
            ItemTextField(_priceController, 'Price (DT)',
                Icons.payments_outlined,
                inputType: const TextInputType.numberWithOptions(decimal: true),
                required: true,
                validator: (v) => switch (AddEditItemController.validatePrice(v)) {
                      ItemPriceError.missing => 'Enter a price',
                      ItemPriceError.notANumber => 'Enter a valid number',
                      ItemPriceError.notPositive => 'Price must be greater than 0',
                      null => null,
                    }),
            const SizedBox(height: 14),
            ItemImagePicker(
              imageFile: s.imageFile,
              imageUrl: _imageUrlController.text,
              onTap: () => c.pickImage(),
            ),
            const SizedBox(height: 24),

            const ItemSectionLabel('Category'),
            const SizedBox(height: 10),
            if (isRestaurant || isVendor)
              _CategorySelector(
                category: _categoryController.text,
                icon: s.categoryIcon,
                onTap: _showCategorySheet,
              )
            else
              _GroceryCategoryDropdown(
                value: s.groceryCategory,
                onChanged: (v) => c.setGroceryCategory(v),
              ),

            // Variants and happy hour have no tables behind vendor_items.
            if (!isVendor) ...[
            const SizedBox(height: 24),
            const ItemSectionLabel('Variants (optional)'),
            const SizedBox(height: 6),
            const Text(
              'Add named options with their own prices (e.g. Small, Medium, '
              'Chocolate, Vanilla). Customers must pick one. Leave empty to '
              'use just the base price above.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            VariantsList(
              variants: _variants,
              onRemove: (i) => setState(() {
                final removed = _variants.removeAt(i);
                removed.dispose();
              }),
            ),
            const SizedBox(height: 8),
            _AddVariantButton(
              onPressed: () => setState(() => _variants.add(VariantDraft())),
            ),
            const SizedBox(height: 24),
            HappyHourSection(
              isHappyHour: s.isHappyHour,
              priceController: _happyHourPriceController,
              start: s.happyHourStart,
              end: s.happyHourEnd,
              onToggle: (v) => c.setHappyHour(v),
              onStart: (t) => c.setHappyHourStart(t),
              onEnd: (t) => c.setHappyHourEnd(t),
            ),
            ],
            const SizedBox(height: 24),
            ItemSectionLabel(isRestaurant ? 'Dish Details' : 'Product Details'),
            const SizedBox(height: 10),

            if (isRestaurant)
              ItemTextField(_prepTimeController, 'Preparation Time (minutes)',
                  Icons.timer_outlined,
                  inputType: TextInputType.number),

            if (!isRestaurant) ...[
              ItemTextField(_unitController, 'Unit (kg, piece, liter…)',
                  Icons.scale_outlined),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 14),
            ItemSwitchTile('Available', 'Show this item to customers',
                Icons.visibility_outlined, s.isAvailable,
                (v) => c.setAvailable(v)),

            if (isRestaurant) ...[
              const Divider(height: 1),
              ItemSwitchTile('Vegetarian', 'Mark as vegetarian',
                  Icons.eco_outlined, s.isVegetarian,
                  (v) => c.setVegetarian(v)),
              const Divider(height: 1),
              ItemSwitchTile('Spicy', 'Mark as spicy',
                  Icons.local_fire_department_outlined, s.isSpicy,
                  (v) => c.setSpicy(v)),
            ],

            if (!isRestaurant && !isVendor) ...[
              const Divider(height: 1),
              ItemSwitchTile('Organic', 'Mark as organic product',
                  Icons.eco_outlined, s.isOrganic,
                  (v) => c.setOrganic(v)),
            ],

            const SizedBox(height: 32),
            _SubmitButton(
              isLoading: s.isLoading,
              label: isEditing ? l.updateItem : l.addItem,
              onPressed: _save,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Form parts, in screen order ──────────────────────────────────────────────

class _SaveAction extends StatelessWidget {
  const _SaveAction({required this.isLoading, required this.onSave});

  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TextButton(
        onPressed: isLoading ? null : onSave,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : Text(l.save,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.category,
    required this.icon,
    required this.onTap,
  });

  final String category;
  final String? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCategory = category.isNotEmpty;
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCategory
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.textLight.withOpacity(0.15),
            width: hasCategory ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            if (hasCategory && icon != null) ...[
              Text(icon!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
            ] else ...[
              const Icon(Icons.category_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                hasCategory ? category : 'Tap to select a category',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasCategory ? FontWeight.w600 : FontWeight.w400,
                  color: hasCategory ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _GroceryCategoryDropdown extends StatelessWidget {
  const _GroceryCategoryDropdown({required this.value, required this.onChanged});

  final GroceryCategory value;
  final ValueChanged<GroceryCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<GroceryCategory>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined,
            color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textLight.withOpacity(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: GroceryCategory.values
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.nameEn),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _AddVariantButton extends StatelessWidget {
  const _AddVariantButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add variant'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  final bool isLoading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
      ),
    );
  }
}
