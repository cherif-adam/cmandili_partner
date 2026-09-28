import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/models/partner_model.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Comment cette boutique remise ses articles, et jusqu'ou.
///
/// La regle vit dans `vendor_categories.discount_mode` : les restaurants et
/// les patisseries font du Happy Hour (un prix reduit, tout de suite), les
/// autres commerces font de la promotion en pourcentage entre deux dates.
/// Ajouter une categorie plus tard ne demande que de renseigner cette colonne
/// -- aucune application n'a a etre modifiee.
@immutable
class ShopSettings {
  /// 'happy_hour' ou 'percent'.
  final String discountMode;

  /// Plafond que l'administrateur fixe dans `global_settings`, jamais code en
  /// dur ici.
  final double maxDiscountPercent;

  const ShopSettings({
    required this.discountMode,
    required this.maxDiscountPercent,
  });

  bool get usesPercent => discountMode == 'percent';
  bool get usesHappyHour => discountMode == 'happy_hour';

  /// Repli hors ligne, quand la table est illisible. La base reste la source
  /// de verite : ces valeurs ne font que reproduire son etat initial pour que
  /// l'ecran ne soit pas vide en cas de coupure.
  static ShopSettings fallbackFor(String categoryId) => ShopSettings(
        discountMode:
            (categoryId == 'food' || categoryId == 'bakery') ? 'happy_hour' : 'percent',
        maxDiscountPercent: 70,
      );
}

final shopSettingsProvider = FutureProvider<ShopSettings>((ref) async {
  final supabase = Supabase.instance.client;
  final profile = await ref.watch(partnerProfileProvider.future);
  final categoryId = vendorCategoryForPartnerType(profile?.partnerType ?? '');

  double maxPercent = 70;
  try {
    final setting = await supabase
        .from('global_settings')
        .select('setting_value')
        .eq('setting_key', 'max_discount_percent')
        .maybeSingle();
    final raw = setting?['setting_value'];
    final parsed = raw == null ? null : double.tryParse(raw.toString());
    if (parsed != null && parsed > 0) maxPercent = parsed;
  } catch (e) {
    debugPrint('[ShopSettings] max_discount_percent illisible: $e');
  }

  try {
    // Volontairement SANS filtre sur is_active. `is_active` veut dire "montrer
    // ce bouton au client sur l'accueil", pas "cette categorie existe" :
    // confondre les deux ferait disparaitre le mode de remise d'une categorie
    // simplement masquee. La categorie 'food' est justement is_active = false
    // en base aujourd'hui.
    final row = await supabase
        .from('vendor_categories')
        .select('discount_mode')
        .eq('id', categoryId)
        .maybeSingle();
    final mode = row?['discount_mode']?.toString();
    if (mode == 'happy_hour' || mode == 'percent') {
      return ShopSettings(discountMode: mode!, maxDiscountPercent: maxPercent);
    }
    debugPrint('[ShopSettings] aucun discount_mode pour "$categoryId", repli');
  } catch (e) {
    debugPrint('[ShopSettings] vendor_categories illisible: $e');
  }

  final fb = ShopSettings.fallbackFor(categoryId);
  return ShopSettings(
    discountMode: fb.discountMode,
    maxDiscountPercent: maxPercent,
  );
});
