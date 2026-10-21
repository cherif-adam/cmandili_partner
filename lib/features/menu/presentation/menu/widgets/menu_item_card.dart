import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/providers/shop_settings_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/promo_price.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/grocery_item.dart';
import '../../../data/models/vendor_item.dart';
import '../../add_edit_item_screen.dart';
import '../../happy_hour_setup/happy_hour_setup_screen.dart';
import '../../promo_setup/promo_setup_screen.dart';
import '../menu_controller.dart';

/// One menu item: photo, name, price and its deal badge, the availability
/// switch (optimistic, rolled back on failure), then edit / deal / delete.
class MenuItemCard extends ConsumerStatefulWidget {
  final dynamic item;
  final bool isRestaurant;
  final String partnerType;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.isRestaurant,
    required this.partnerType,
  });

  @override
  ConsumerState<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends ConsumerState<MenuItemCard> {
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _initAvailability();
  }

  @override
  void didUpdateWidget(covariant MenuItemCard oldWidget) {
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
      final menu = ref.read(menuControllerProvider.notifier);
      final success = await menu.setAvailability(
        itemId,
        value,
        isGrocery: isGrocery,
        isVendor: isVendor,
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
        menu.refreshMenu();
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
                  ).then((_) => ref.read(menuControllerProvider.notifier).refreshMenu()),
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
                    ).then((_) => ref.read(menuControllerProvider.notifier).refreshMenu()),
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
                    ).then((_) => ref.read(menuControllerProvider.notifier).refreshMenu()),
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
              await ref.read(menuControllerProvider.notifier).deleteItem(
                    itemId,
                    isRestaurant: isRestaurant,
                    isVendor: isVendor,
                  );
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
