import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/providers/partner_orders_provider.dart';
import '../data/payout_repository.dart';

final payoutRepositoryProvider =
    Provider<PayoutRepository>((ref) => PayoutRepository());

/// Prepaid wallet balance for the signed-in partner. Balance <= 0 means the
/// restaurant is blocked from receiving orders until the admin tops it up.
///
/// LIVE. This used to be read once: the dashboard that shows it stays mounted
/// for the whole session, so the balance a partner saw was the one from when
/// they logged in, however many orders had been delivered since. It is now
/// re-read:
///   * the moment any of the shop's orders changes;
///   * every 15 s while the app is on screen;
///   * when the app comes back to the front (the home screen restarts the
///     orders stream on resume, which lands here).
final partnerWalletProvider = StreamProvider.autoDispose<double?>((ref) {
  final controller = StreamController<double?>();
  final repository = ref.read(payoutRepositoryProvider);
  Timer? settle;
  var closed = false;

  Future<void> refresh() async {
    final userId = repository.currentUserId;
    if (userId == null) {
      if (!closed) controller.add(null);
      return;
    }
    try {
      final balance = await repository.walletBalance(userId);
      if (!closed) controller.add(balance);
    } catch (e) {
      // Offline etc: keep showing the last known balance; the next trigger
      // tries again. An error state would blank the card.
      debugPrint('wallet refresh failed: $e');
    }
  }

  refresh();

  // The moment an order changes. The server writes the commission and the
  // new balance in the same transaction that marks an order delivered, so by
  // the time the order event arrives the wallet is already up to date. One
  // more read two seconds later covers anything the server settles after.
  ref.listen(partnerOrdersStreamProvider, (_, __) {
    refresh();
    settle?.cancel();
    settle = Timer(const Duration(seconds: 2), refresh);
  });

  // Safety net, and what picks up changes that are not tied to an order (an
  // admin top-up): `wallets` is not in the realtime publication, so nothing
  // announces those. Only while the app is on screen.
  final poll = Timer.periodic(const Duration(seconds: 15), (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      refresh();
    }
  });

  ref.onDispose(() {
    closed = true;
    poll.cancel();
    settle?.cancel();
    controller.close();
  });
  return controller.stream;
});
