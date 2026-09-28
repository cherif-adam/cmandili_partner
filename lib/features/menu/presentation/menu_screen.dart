import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/providers/shop_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/promo_price.dart';
import '../providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/food_item.dart';
import '../data/models/grocery_item.dart';
import '../data/models/vendor_item.dart';
import 'add_edit_item_screen.dart';
import 'happy_hour_setup_screen.dart';
import 'promo_setup_screen.dart';
import '../providers/menu_scanner_provider.dart';
import 'package:image_picker/image_picker.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(partnerProfileProvider);
    final itemsAsync = ref.watch(filteredMenuItemsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isRestaurant = profileAsync.value?.partnerType == 'restaurant';
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

    final scannerState = ref.watch(menuScannerProvider);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: Colors.transparent,
            actions: [
              if (usesPercent)
                IconButton(
                  icon: const Icon(Icons.sell_rounded, color: Colors.white),
                  tooltip: 'Promo sur une catégorie',
                  onPressed: () => _showCategoryPromoSheet(context),
                ),
              IconButton(
                icon: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                tooltip: l.scanMenu,
                onPressed: scannerState.isLoading
                    ? null
                    : () => _showImageSourceBottomSheet(context, ref),
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
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: l.searchItems,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
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
          ),

          // Category filter chips
          itemsAsync.when(
            data: (items) {
              final categories = _extractCategories(items);
              if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _categoryChip(null, l.all, selectedCategory),
                        ...categories.map(
                            (c) => _categoryChip(c, c, selectedCategory)),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Items list
          itemsAsync.when(
            data: (items) {
              final filtered = _searchQuery.isEmpty
                  ? items
                  : items.where((item) {
                      final name = switch (item) {
                        FoodItem i => i.name.toLowerCase(),
                        GroceryItem i => i.name.toLowerCase(),
                        VendorItem i => i.name.toLowerCase(),
                        _ => '',
                      };
                      return name.contains(_searchQuery);
                    }).toList();

              if (filtered.isEmpty) {
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
                          _searchQuery.isNotEmpty
                              ? '${l.noItemsMatch} "$_searchQuery"'
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
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: scannerState.isLoading
                                ? null
                                : () => _showImageSourceBottomSheet(context, ref),
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

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MenuItemCard(
                        item: filtered[index],
                        isRestaurant: isRestaurant,
                        partnerType: profileAsync.value?.partnerType ?? 'restaurant',
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
          ),
        ],
      ),
      if (scannerState.isLoading)
        Container(
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
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goToAddEdit(context, ref,
            partnerType: profileAsync.value?.partnerType ?? 'restaurant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          // The localized string already contains the verb, so the old
          // 'Add ' prefix rendered "Add Add Dish". Every non-restaurant
          // type (bakery, flowers, pets, gifts, electronics) shares the
          // generic "produit" wording rather than a per-category noun.
          profileAsync.value?.partnerType == 'restaurant'
              ? l.addDish
              : l.addProduct,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _categoryChip(String? value, String label, String? selected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => ref.read(selectedCategoryProvider.notifier).state = value,
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

  /// Choix de la rubrique à remiser en une action.
  ///
  /// Le commerçant choisit une rubrique de SA boutique ("Bouquets",
  /// "Boissons"), pas la catégorie de commerce : c'est à ce niveau qu'une
  /// bradèrie se décide. Le nombre d'articles est affiché parce qu'une remise
  /// posée sur 40 références d'un seul geste mérite d'être comptée avant, pas
  /// découverte après.
  void _showCategoryPromoSheet(BuildContext context) {
    final items = ref.read(menuItemsProvider).valueOrNull ?? const [];
    final vendorId = ref.read(partnerProfileProvider).valueOrNull?.entityId;
    final categories = _extractCategories(items);

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
                  final count = _countInCategory(items, c);
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
                      ).then((_) => ref.invalidate(menuItemsProvider));
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

  int _countInCategory(List<dynamic> items, String category) {
    return items.where((item) {
      if (item is FoodItem) return item.category == category;
      if (item is GroceryItem) {
        return item.category.toString().split('.').last == category;
      }
      if (item is VendorItem) return item.category == category;
      return false;
    }).length;
  }

  List<String> _extractCategories(List<dynamic> items) {
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

  void _goToAddEdit(BuildContext context, WidgetRef ref,
      {required String partnerType,
      FoodItem? foodItem,
      GroceryItem? groceryItem,
      VendorItem? vendorItem}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(
          partnerType: partnerType,
          existingFoodItem: foodItem,
          existingGroceryItem: groceryItem,
          existingVendorItem: vendorItem,
        ),
      ),
    ).then((_) => ref.invalidate(menuItemsProvider));
  }

  void _showImageSourceBottomSheet(BuildContext context, WidgetRef ref) {
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
                  ref.read(menuScannerProvider.notifier).scanPhysicalMenu(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                title: Text(l.chooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(menuScannerProvider.notifier).scanPhysicalMenu(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends ConsumerStatefulWidget {
  final dynamic item;
  final bool isRestaurant;
  final String partnerType;

  const _MenuItemCard({
    required this.item,
    required this.isRestaurant,
    required this.partnerType,
  });

  @override
  ConsumerState<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends ConsumerState<_MenuItemCard> {
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _initAvailability();
  }

  @override
  void didUpdateWidget(covariant _MenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _initAvailability();
    }
  }

  void _initAvailability() {
    final fi = widget.item is FoodItem ? widget.item as FoodItem : null;
    final gi = widget.item is GroceryItem ? widget.item as GroceryItem : null;
    final vi = widget.item is VendorItem ? widget.item as VendorItem : null;
    _isAvailable = fi?.isAvailable ?? gi?.isAvailable ?? vi?.isAvailable ?? true;
  }

  Future<void> _toggleAvailability(bool value) async {
    final previousState = _isAvailable;
    
    // 1. Optimistic update
    setState(() => _isAvailable = value);

    final isGrocery = widget.item is GroceryItem;
    final isVendor = widget.item is VendorItem;

    final itemId = switch (widget.item) {
      FoodItem i => i.id,
      GroceryItem i => i.id,
      VendorItem i => i.id,
      _ => '',
    };

    if (itemId.isEmpty) {
      if (mounted) {
        setState(() => _isAvailable = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur: ID introuvable', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // 2. Call backend
      final repo = ref.read(menuRepositoryProvider);
      // updateItemAvailability only knows the two legacy views; vendor items
      // live in their own table.
      final success = isVendor
          ? await repo.updateVendorItem(itemId, {'is_available': value})
          : await repo.updateItemAvailability(
              itemId,
              value,
              isGrocery: isGrocery,
            );

      // 3. Handle failure (Rollback)
      if (!success) {
        if (mounted) {
          setState(() => _isAvailable = previousState);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur: Impossible de mettre à jour la disponibilité', style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else {
        // Background silent refresh for global state
        ref.invalidate(menuItemsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAvailable = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fi = widget.item is FoodItem ? widget.item as FoodItem : null;
    final gi = widget.item is GroceryItem ? widget.item as GroceryItem : null;
    final vi = widget.item is VendorItem ? widget.item as VendorItem : null;

    final name = fi?.name ?? gi?.name ?? vi?.name ?? '';
    final price = fi?.price ?? gi?.price ?? vi?.price ?? 0.0;
    final imageUrl = fi?.imageUrl ?? gi?.imageUrl ?? vi?.imageUrl ?? '';
    final category = fi?.category ??
        gi?.category.toString().split('.').last ??
        vi?.category ??
        '';
    final discountPrice =
        fi?.discountPrice ?? gi?.discountPrice ?? vi?.discountPrice;
    final discountEndTime =
        fi?.discountEndTime ?? gi?.discountEndTime ?? vi?.discountEndTime;
    final discountQuantity =
        fi?.discountQuantity ?? gi?.discountQuantity ?? vi?.discountQuantity;
    // A deal with no end date runs until the partner stops it, so only a
    // price is required; one with an end is live until that moment passes.
    final parsedEnd = discountEndTime != null
        ? DateTime.tryParse(discountEndTime)?.toLocal()
        : null;
    final hasHappyHour = discountPrice != null &&
        (parsedEnd == null || parsedEnd.isAfter(DateTime.now()));
    final itemId = fi?.id ?? gi?.id ?? vi?.id ?? '';

    // Le mode de remise vient de la categorie de la boutique, pas du type
    // d'article : la meme carte sert un restaurant (Happy Hour) et un
    // fleuriste (promotion en pourcentage).
    final usesPercent =
        ref.watch(shopSettingsProvider).valueOrNull?.usesPercent ?? false;
    final promoColor = usesPercent ? AppColors.primary : AppColors.secondary;

    // FoodItem ne porte pas ces colonnes : la categorie food est en Happy
    // Hour, elle n'a pas de pourcentage a afficher.
    final discountPercent = gi?.discountPercent ?? vi?.discountPercent;
    final discountStartTime = gi?.discountStartTime ?? vi?.discountStartTime;
    final parsedStart = discountStartTime != null
        ? DateTime.tryParse(discountStartTime)?.toLocal()
        : null;

    // Une promotion PROGRAMMEE porte son taux sans porter encore son prix :
    // celui-ci n'est pose qu'a l'instant du debut, pour qu'aucun ecran client
    // ne fasse partir la remise en avance. Sans cet etat, le commercant qui
    // programme une braderie pour samedi ne verrait rien sur sa carte et
    // croirait que l'enregistrement a echoue.
    final isScheduled = discountPrice == null &&
        discountPercent != null &&
        (parsedEnd == null || parsedEnd.isAfter(DateTime.now()));

    // Le taux stocke s'il existe, sinon deduit des deux prix -- une remise
    // posee depuis l'ecran Happy Hour n'enregistre qu'un prix.
    final shownPercent =
        discountPercent ?? percentFromPrices(price, discountPrice);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (hasHappyHour)
                            _badge(
                              icon: usesPercent
                                  ? Icons.sell_rounded
                                  : Icons.local_fire_department_rounded,
                              label: usesPercent && shownPercent != null
                                  ? '−${_trimPercent(shownPercent)} %'
                                  : l.happyHourBadge,
                              color: promoColor,
                            )
                          else if (isScheduled)
                            _badge(
                              icon: Icons.schedule_rounded,
                              label: '−${_trimPercent(discountPercent)} %',
                              color: AppColors.info,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(category,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            hasHappyHour
                                ? '${discountPrice.toStringAsFixed(2)} DT'
                                : '${price.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: hasHappyHour
                                  ? promoColor
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (hasHappyHour) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${price.toStringAsFixed(2)} DT',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            // Remaining units of a limited batch, counted
                            // down by the database as customers order.
                            if (discountQuantity != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                l.hhUnitsLeft(discountQuantity),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      if (isScheduled && parsedStart != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Démarre le ${_formatShort(parsedStart)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info),
                        ),
                      ],
                    ],
                  ),
                ),

                // Availability switch
                Switch(
                  value: _isAvailable,
                  activeColor: AppColors.primary,
                  onChanged: _toggleAvailability,
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppColors.textLight.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                _actionButton(
                  context,
                  icon: Icons.edit_rounded,
                  label: l.edit,
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditItemScreen(
                        partnerType: widget.partnerType,
                        existingFoodItem: fi,
                        existingGroceryItem: gi,
                        existingVendorItem: vi,
                      ),
                    ),
                  ).then((_) => ref.invalidate(menuItemsProvider)),
                ),
                // Every category, vendor items included: the setup writes
                // vendor_items directly, where all item ids live.
                //
                // Happy Hour ou Promotion : la catégorie de la boutique
                // tranche, pas l'écran. Un restaurant pose un prix tout de
                // suite, un fleuriste programme un pourcentage entre deux
                // dates -- ce sont deux gestes de commerce différents, pas
                // deux habillages du même bouton.
                _divider(),
                if (usesPercent)
                  _actionButton(
                    context,
                    icon: Icons.sell_rounded,
                    label: 'Promo',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromoSetupScreen(
                          itemId: itemId,
                          itemName: name,
                          originalPrice: price,
                          currentDiscountPrice: discountPrice,
                          currentPercent: shownPercent,
                          currentStartTime: parsedStart,
                          currentEndTime: parsedEnd,
                        ),
                      ),
                    ).then((_) => ref.invalidate(menuItemsProvider)),
                  )
                else
                  _actionButton(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    label: l.happyHour,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HappyHourSetupScreen(
                          itemId: itemId,
                          itemName: name,
                          originalPrice: price,
                          currentDiscountPrice: discountPrice,
                          currentEndTime: parsedEnd,
                          currentQuantity: discountQuantity,
                        ),
                      ),
                    ).then((_) => ref.invalidate(menuItemsProvider)),
                  ),
                _divider(),
                _actionButton(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: l.deleteAction,
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, itemId,
                      isRestaurant: widget.isRestaurant, isVendor: vi != null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pastille de remise, la même forme pour les trois états (Happy Hour,
  /// promotion en cours, promotion programmée) : seuls l'icône, le texte et
  /// la couleur changent.
  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  /// "20", pas "20.0" : un taux entier s'écrit sans décimale.
  static String _trimPercent(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  static String _formatShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} à ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.background,
      child: const Icon(Icons.image_outlined,
          color: AppColors.textLight, size: 32),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.textLight.withOpacity(0.1));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String itemId,
      {required bool isRestaurant, required bool isVendor}) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.deleteItem,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(l.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(menuRepositoryProvider);
              if (isRestaurant) {
                await repo.deleteFoodItem(itemId);
              } else if (isVendor) {
                await repo.deleteVendorItem(itemId);
              } else {
                await repo.deleteGroceryItem(itemId);
              }
              ref.invalidate(menuItemsProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l.deleteAction,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
