import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/models/order.dart';
import '../../providers/partner_orders_provider.dart';

/// The order screen's logic. Its state is whether a self-delivery
/// confirmation is being sent. Like the provider it replaces, it is shared
/// by the order screens on display and starts again at false once none of
/// them is left.
final orderDetailControllerProvider =
    NotifierProvider.autoDispose<OrderDetailController, bool>(
        OrderDetailController.new);

class OrderDetailController extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  // ── User actions ──────────────────────────────────────────────────────────

  /// The statuses the partner may move [current] to, for this shop's type.
  List<OrderStatus> nextStatusesFor(OrderStatus current, {bool selfDelivery = false}) {
    final partnerType = ref.read(partnerProfileProvider).valueOrNull?.partnerType;
    return nextStatuses(
      current,
      // Par defaut on garde l'etape de preparation : si le profil n'est pas
      // encore charge, mieux vaut un bouton de trop qu'un statut saute.
      skipsPreparation: partnerType != null && partnerType != 'restaurant',
      selfDelivery: selfDelivery,
    );
  }

  /// Throws when the update is refused.
  Future<bool> updateStatus(String orderId, OrderStatus status) =>
      ref.read(partnerOrderRepositoryProvider).updateOrderStatus(orderId, status);

  /// Whether the order was still cancellable. Throws on a network error.
  Future<bool> cancel(String orderId, String reason) =>
      ref.read(partnerOrderRepositoryProvider).cancelOrderByPartner(orderId, reason);

  /// The partner delivers the order themself. Returns the error, if any;
  /// the banner then calls [selfDeliveryDone] while it is still shown.
  Future<Object?> confirmSelfDelivery(String orderId) async {
    state = true;
    try {
      await ref.read(partnerOrderRepositoryProvider).confirmSelfDelivery(orderId);
      // The realtime subscription on orders will update the UI automatically.
      // Status is now 'on_the_way' — partner uses the existing mark-delivered flow.
      return null;
    } catch (e) {
      return e;
    }
  }

  void selfDeliveryDone() => state = false;

  // ── Rules ─────────────────────────────────────────────────────────────────

  /// The shop may still pull an order back while it holds the goods. Mirrors
  /// the `inFilter` guard in [PartnerOrderRepository.cancelOrderByPartner] —
  /// the button hides for the same statuses the server refuses, so the UI
  /// never offers an action that would silently fail.
  static bool canPartnerCancel(Order order) =>
      order.status == OrderStatus.pending ||
      order.status == OrderStatus.confirmed ||
      order.status == OrderStatus.preparing ||
      order.status == OrderStatus.ready;

  static const partnerCancelReasons = [
    'Article en rupture de stock',
    'Boutique fermée',
    'Problème en cuisine',
    'Commande en double',
    'Autre',
  ];

  static bool showSelfDeliveryBanner(Order o) {
    // Show the banner when:
    //  - The DB has recorded that all drivers were exhausted (no_driver_notified_at set)
    //  - The partner hasn't chosen self-delivery yet
    //  - No driver has accepted the order
    //  - The order is still awaiting delivery (ready or confirmed)
    return o.noDriverNotifiedAt != null &&
        !o.selfDelivery &&
        o.driverId == null &&
        (o.status == OrderStatus.ready || o.status == OrderStatus.confirmed);
  }

  /// Seuls les restaurants preparent. Pour toutes les autres categories --
  /// supermarche, patisserie, fleurs, animalerie, cadeaux, electronique -- la
  /// commande est rassemblee sur place et passe directement de Acceptee a
  /// Prete : afficher un bouton "Preparer" leur ferait ajouter une etape qui
  /// ne correspond a rien de leur cote.
  ///
  /// Derive de partner_type plutot que d'un drapeau par boutique : la regle
  /// est bien par categorie, et aucun attribut de ce genre n'existe en base
  /// (le `sansPreparation` du diagramme de classes n'a jamais ete implemente).
  /// Sauter `preparing` ne change rien cote base : aucun trigger ni contrainte
  /// n'impose l'ordre des statuts, le dispatch livreur se declenche sur
  /// l'entree en 'ready' quel que soit le statut precedent, et `confirmed_at`
  /// comme `ready_at` sont horodates sur leurs propres statuts.
  ///
  /// « Livree » seulement pour une commande que la boutique livre elle-meme :
  /// portee par un livreur, c'est lui qui la livre (la base le refuse au
  /// partenaire).
  static List<OrderStatus> nextStatuses(OrderStatus current,
      {required bool skipsPreparation, bool selfDelivery = false}) {
    switch (current) {
      case OrderStatus.pending: return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [
          skipsPreparation ? OrderStatus.ready : OrderStatus.preparing,
          OrderStatus.cancelled,
        ];
      case OrderStatus.preparing: return [OrderStatus.ready];
      case OrderStatus.ready: return [OrderStatus.pickedUp, OrderStatus.onTheWay];
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay: return selfDelivery ? [OrderStatus.delivered] : [];
      default: return [];
    }
  }
}
