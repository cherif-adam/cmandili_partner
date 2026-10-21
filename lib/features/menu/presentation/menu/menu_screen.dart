import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/providers/shop_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/menu_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../add_edit_item_screen.dart';
import '../promo_setup/promo_setup_screen.dart';
import '../../providers/menu_scanner_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'menu_controller.dart';
import 'widgets/menu_item_card.dart';

/// The menu tab: header, search, category chips, then the items (or the
/// empty state), with the scan overlay on top while a menu photo is read.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchController = TextEditingController();

  PartnerMenuController get _controller =>
      ref.read(menuControllerProvider.notifier);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(menuControllerProvider);
    final profileAsync = ref.watch(partnerProfileProvider);
    final itemsAsync = ref.watch(filteredMenuItemsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isRestaurant = profileAsync.value?.partnerType == 'restaurant';
    final partnerType = profileAsync.value?.partnerType ?? 'restaurant';
    final l = AppLocalizations.of(context)!;
    // Les commerces en pourcentage peuvent remiser toute une rubrique d'un
    // coup ; un restaurant pose ses Happy Hour plat par plat, l'action n'a pas
    // de sens pour lui et n'apparaît donc pas.
    final usesPercent =
        ref.watch(shopSettingsProvider).valueOrNull?.usesPercent ?? false;

    ref.listen<MenuScannerState>(menuScannerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.scanMenuError}: ${next.error}'), backgroundColor: AppColors.error),
        );
      } else if (next.itemsAddedCount != null && next.itemsAddedCount != previous?.itemsAddedCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.scanMenuSuccess} (${next.itemsAddedCount} items)'), backgroundColor: Colors.green),
        );
      }
    });

    final scanning = ref.watch(menuScannerProvider).isLoading;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _MenuHeader(
                isRestaurant: isRestaurant,
                usesPercent: usesPercent,
                scanning: scanning,
                onCategoryPromo: () => _showCategoryPromoSheet(context),
                onScan: () => _showImageSourceBottomSheet(context),
              ),
              _SearchBar(
                controller: _searchController,
                query: query,
                onChanged: (v) => _controller.setQuery(v),
                onClear: () {
                  _searchController.clear();
                  _controller.clearQuery();
                },
              ),
              _CategoryChips(
                itemsAsync: itemsAsync,
                selected: selectedCategory,
                onSelect: (v) => _controller.selectCategory(v),
              ),
              _ItemsList(
                itemsAsync: itemsAsync,
                filter: (items) => _controller.filterBySearch(items),
                query: query,
                isRestaurant: isRestaurant,
                partnerType: partnerType,
                scanning: scanning,
                onScan: () => _showImageSourceBottomSheet(context),
              ),
            ],
          ),
          if (scanning) const _ScanOverlay(),
        ],
      ),
      floatingActionButton: _AddItemButton(
        isRestaurant: isRestaurant,
        onPressed: () => _goToAddEdit(context, partnerType: partnerType),
      ),
    );
  }

  /// Choix de la rubrique à remiser en une action.
  ///
  /// Le commerçant choisit une rubrique de SA boutique ("Bouquets",
  /// "Boissons"), pas la catégorie de commerce : c'est à ce niveau qu'une
  /// bradèrie se décide. Le nombre d'articles est affiché parce qu'une remise
  /// posée sur 40 références d'un seul geste mérite d'être comptée avant, pas
  /// découverte après.
  void _showCategoryPromoSheet(BuildContext context) {
    final (:items, :vendorId) = _controller.categoryPromoSource();
    final categories = PartnerMenuController.extractCategories(items);

    if (vendorId == null || categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune rubrique à remiser pour le moment.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Promo sur une catégorie',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Le même pourcentage sur tous les articles de la rubrique.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: categories.map((c) {
                  final count = PartnerMenuController.countInCategory(items, c);
                  return ListTile(
                    leading: const Icon(Icons.sell_rounded,
                        color: AppColors.primary),
                    title: Text(c),
                    subtitle: Text('$count article(s)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PromoSetupScreen(
                            itemName: c,
                            originalPrice: 0,
                            categoryName: c,
                            vendorId: vendorId,
                            categoryItemCount: count,
                          ),
                        ),
                      ).then((_) => _controller.refreshMenu());
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _goToAddEdit(BuildContext context, {required String partnerType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(partnerType: partnerType),
      ),
    ).then((_) => _controller.refreshMenu());
  }

  void _showImageSourceBottomSheet(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text(l.takePhoto, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.scanMenu(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                title: Text(l.chooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.scanMenu(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sections, in screen order ────────────────────────────────────────────────

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.isRestaurant,
    required this.usesPercent,
    required this.scanning,
    required this.onCategoryPromo,
    required this.onScan,
  });

  final bool isRestaurant;
  final bool usesPercent;
  final bool scanning;
  final VoidCallback onCategoryPromo;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.transparent,
      actions: [
        if (usesPercent)
          IconButton(
            icon: const Icon(Icons.sell_rounded, color: Colors.white),
            tooltip: 'Promo sur une catégorie',
            onPressed: onCategoryPromo,
          ),
        IconButton(
          icon: const Icon(Icons.document_scanner_rounded, color: Colors.white),
          tooltip: l.scanMenu,
          onPressed: scanning ? null : onScan,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRestaurant ? l.menu : l.products,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRestaurant
                        ? l.manageDishesHappyHour
                        : l.manageProductsHappyHour,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: l.searchItems,
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: AppColors.textSecondary),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.itemsAsync,
    required this.selected,
    required this.onSelect,
  });

  final AsyncValue<List<dynamic>> itemsAsync;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return itemsAsync.when(
      data: (items) {
        final categories = PartnerMenuController.extractCategories(items);
        if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                      value: null, label: l.all, selected: selected, onSelect: onSelect),
                  ...categories.map((c) => _CategoryChip(
                      value: c, label: c, selected: selected, onSelect: onSelect)),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String? value;
  final String label;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.itemsAsync,
    required this.filter,
    required this.query,
    required this.isRestaurant,
    required this.partnerType,
    required this.scanning,
    required this.onScan,
  });

  final AsyncValue<List<dynamic>> itemsAsync;
  final List<dynamic> Function(List<dynamic> items) filter;
  final String query;
  final bool isRestaurant;
  final String partnerType;
  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return itemsAsync.when(
      data: (items) {
        final filtered = filter(items);

        if (filtered.isEmpty) {
          return _EmptyMenu(
            query: query,
            isRestaurant: isRestaurant,
            scanning: scanning,
            onScan: onScan,
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MenuItemCard(
                  item: filtered[index],
                  isRestaurant: isRestaurant,
                  partnerType: partnerType,
                ),
              ),
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        child: Center(
          child: Text(
            l.couldNotLoadItems,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({
    required this.query,
    required this.isRestaurant,
    required this.scanning,
    required this.onScan,
  });

  final String query;
  final bool isRestaurant;
  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRestaurant
                  ? Icons.restaurant_menu_rounded
                  : Icons.store_rounded,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? '${l.noItemsMatch} "$query"'
                  : l.noItemsYet,
              style:
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
            ),
            const SizedBox(height: 8),
            Text(
              l.tapToAddFirst,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textLight,
                      ),
            ),
            if (query.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: scanning ? null : onScan,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(l.scanMenuEmptyState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                l.scanMenuLoading,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.isRestaurant, required this.onPressed});

  final bool isRestaurant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        // The localized string already contains the verb, so the old
        // 'Add ' prefix rendered "Add Add Dish". Every non-restaurant
        // type (bakery, flowers, pets, gifts, electronics) shares the
        // generic "produit" wording rather than a per-category noun.
        isRestaurant ? l.addDish : l.addProduct,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
