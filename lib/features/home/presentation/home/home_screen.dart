import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/profile/profile_screen.dart';
import '../../../orders/presentation/partner_orders/partner_orders_screen.dart';
import '../../../menu/presentation/menu/menu_screen.dart';
import '../../../reports/presentation/reports/reports_screen.dart';
import '../../../orders/providers/partner_orders_provider.dart';
import '../../../auth/data/models/partner_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/not_a_partner/not_a_partner_screen.dart';
import '../../../orders/providers/audio_alert_provider.dart';
import '../../../orders/data/models/order.dart';
import '../../../orders/presentation/incoming_order_dialog.dart';
import '../../../../core/widgets/background_guide.dart';
import 'home_controller.dart';
import 'widgets/advance_status_button.dart';
import 'widgets/balance_card.dart';
import 'widgets/quick_stat_card.dart';
import 'widgets/schedule_section.dart';

// HomeScreen hosts the incoming-order alarm (one dialog at a time, the
// alarm sound, a re-fetch on resume) and the tabs; it and
// _PendingOrderActions (Accept also silences the alarm) are kept exactly as
// they were. The dashboard tab is built from the sections below; its logic
// is in home_controller.dart, its data in ShopStatusRepository.

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// IDs of pending orders for which a dialog has already been shown this
  /// session. Prevents the same order from triggering multiple dialogs if
  /// the stream emits it again (e.g. on reconnect).
  final Set<String> _shownPendingIds = {};

  /// New orders waiting to be shown, one dialog at a time (a burst of orders
  /// must not spawn overlapping dialogs — see [_maybeShowNextDialog]).
  final List<Order> _dialogQueue = [];
  bool _dialogShowing = false;

  final List<Widget> _tabs = const [
    _DashboardTab(),
    PartnerOrdersScreen(),
    MenuScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // On phones that kill background apps, tell the owner how to let the
    // order alarm through (once; see BackgroundGuide).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BackgroundGuide.maybeShow(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Realtime's websocket is commonly suspended by the OS while backgrounded
  /// (screen lock included) and does not replay events missed in that gap —
  /// it's live-only, not a durable queue. On resume we can't tell whether the
  /// socket silently died or just went idle, so unconditionally invalidating
  /// forces a clean channel + a full re-fetch either way, catching anything
  /// missed while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(partnerOrdersStreamProvider);
      ref.invalidate(dashboardStatsProvider);
    }
  }

  /// Queues the incoming-order dialog for [order]. Dialogs are shown one at a
  /// time in arrival order — a burst of several orders queues instead of
  /// stacking overlapping routes, and none are dropped.
  void _enqueueIncomingOrder(Order order) {
    _dialogQueue.add(order);
    _maybeShowNextDialog();
  }

  void _maybeShowNextDialog() {
    if (_dialogShowing || _dialogQueue.isEmpty) return;
    _dialogShowing = true;
    final order = _dialogQueue.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _dialogShowing = false;
        return;
      }
      await showDialog(
        context: context,
        barrierDismissible: false, // partner must explicitly accept or reject
        builder: (_) => IncomingOrderDialog(order: order),
      );
      _dialogShowing = false;
      if (mounted) _maybeShowNextDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(partnerProfileProvider);
    final l = AppLocalizations.of(context)!;

    // Démarre l'écoute globale pour les alertes sonores de nouvelles commandes
    ref.listen(orderAlertProvider, (_, __) {});

    // Detect new pending orders and queue the incoming-order dialog once per
    // order ID (queueing — not showing directly — is what keeps a burst of
    // several orders from spawning overlapping dialogs; see
    // _maybeShowNextDialog). Fires on every stream emission: the initial
    // fetch (login), a live Realtime change, and the resume-triggered
    // invalidation in didChangeAppLifecycleState all funnel through here
    // identically, so nothing extra is needed to handle them differently.
    ref.listen<AsyncValue<List<Order>>>(partnerOrdersStreamProvider,
        (_, next) {
      next.whenData((orders) {
        for (final order in orders) {
          if (order.status == OrderStatus.pending &&
              !_shownPendingIds.contains(order.id)) {
            _shownPendingIds.add(order.id);
            _enqueueIncomingOrder(order);
          }
        }
      });
    });

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading profile: $err'))),
      data: (profile) {
        if (profile == null) {
          // Connecte, mais sans boutique. Ce n'est PAS forcement un partenaire
          // qui debute : ce peut etre un administrateur, un client, un
          // livreur, ou quelqu'un qui s'est trompe de compte. Ouvrir la
          // configuration ici a cree une seconde boutique le 30/09, sur un nom
          // tape pour en retrouver une autre.
          return const NotAPartnerScreen();
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _tabs,
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, l.dashboard),
                  _buildNavItem(1, Icons.receipt_long_rounded, l.orders),
                  _buildNavItem(2, Icons.restaurant_menu_rounded, l.menu),
                  _buildNavItem(3, Icons.insights_rounded, l.reports),
                  _buildNavItem(4, Icons.person_rounded, l.profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard tab ────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dashboardControllerProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final ordersAsync = ref.watch(partnerOrdersStreamProvider);
    final profileAsync = ref.watch(partnerProfileProvider);

    return CustomScrollView(
      slivers: [
        _DashboardHeader(statsAsync: statsAsync, profileAsync: profileAsync),
        _QuickStats(statsAsync: statsAsync),
        // Shop open/closed toggle
        _ShopOpenToggle(profileAsync: profileAsync),

        // Operating hours schedule — optional, placed directly below the manual toggle
        _ScheduleRow(profileAsync: profileAsync),

        // Prepaid balance. The platform commission is deducted from this on
        // every delivered order, and the restaurant stops receiving orders
        // when it hits zero -- so it belongs on the dashboard, not buried in
        // the profile tab where it was the only place it appeared.
        const SliverToBoxAdapter(child: BalanceCard()),

        const _ActiveOrdersHeader(),
        _ActiveOrdersList(ordersAsync: ordersAsync),
        const _QuickActions(),
      ],
    );
  }
}

// ── Dashboard sections, in screen order ──────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.statsAsync, required this.profileAsync});

  final AsyncValue<Map<String, dynamic>> statsAsync;
  final AsyncValue<PartnerProfile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.24,
      pinned: true,
      backgroundColor: Colors.transparent,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.partnerDashboard,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          profileAsync.when(
                            data: (profile) => Text(
                              profile?.businessName ?? 'Amana Partner',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                            loading: () => const SizedBox(
                              width: 60,
                              child: LinearProgressIndicator(color: Colors.white54),
                            ),
                            error: (_, __) => Text(
                              'Amana Partner',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  statsAsync.when(
                    data: (stats) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.revenueToday,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(double.tryParse(stats['revenue']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)} DT',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  l.orders,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${stats['orderCount'] ?? 0}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(l.couldNotLoadStats, style: const TextStyle(color: Colors.white70)),
                      ),
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

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.statsAsync});

  final AsyncValue<Map<String, dynamic>> statsAsync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: QuickStatCard(
                  icon: Icons.timer_rounded,
                  label: l.avgPrep,
                  value: statsAsync.when(
                    data: (s) => '${s['avgPrepTime'] ?? '--'} min',
                    loading: () => '-- min',
                    error: (_, __) => '-- min',
                  ),
                  color: AppColors.accent,
                )),
                const SizedBox(width: 14),
                Expanded(child: QuickStatCard(
                  icon: Icons.star_rounded,
                  label: l.rating,
                  value: statsAsync.when(
                    data: (s) => '${s['rating'] ?? '--'}',
                    loading: () => '--',
                    error: (_, __) => '--',
                  ),
                  color: AppColors.star,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopOpenToggle extends ConsumerWidget {
  const _ShopOpenToggle({required this.profileAsync});

  final AsyncValue<PartnerProfile?> profileAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) return const SizedBox.shrink();
            final isOpen = ref.watch(shopOpenControllerProvider);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (isOpen ?? true) ? Colors.green.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isOpen ?? true) ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isOpen ?? true) ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (isOpen ?? true) ? l.shopOpen : l.shopClosed,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: (isOpen ?? true) ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isOpen ?? true,
                    activeColor: Colors.green,
                    onChanged: (_) => ref.read(shopOpenControllerProvider.notifier).toggle(profile.entityId, profile.partnerType),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.profileAsync});

  final AsyncValue<PartnerProfile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) return const SizedBox.shrink();
            return ScheduleSection(profile: profile);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ActiveOrdersHeader extends StatelessWidget {
  const _ActiveOrdersHeader();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.activeOrders,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => (context.findAncestorStateOfType<_HomeScreenState>()?._selectedIndex = 1),
              child: Text(l.seeAll),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrdersList extends StatelessWidget {
  const _ActiveOrdersList({required this.ordersAsync});

  final AsyncValue<List<Order>> ordersAsync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ordersAsync.when(
      data: (orders) {
        final active = DashboardController.activeOrders(orders);
        if (active.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textLight),
                    const SizedBox(height: 8),
                    Text(
                      l.noActiveOrders,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final order = active[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _DashboardOrderCard(order: order),
              );
            },
            childCount: active.length > 3 ? 3 : active.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Could not load orders', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.quickActions,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final actions = [
                    {'label': l.newMenu, 'icon': Icons.restaurant_menu_rounded, 'color': AppColors.primary, 'tab': 2},
                    {'label': l.promos, 'icon': Icons.local_offer_rounded, 'color': AppColors.secondary, 'tab': 2},
                    {'label': l.reports, 'icon': Icons.insights_rounded, 'color': AppColors.info, 'tab': 3},
                    {'label': l.orders, 'icon': Icons.receipt_long_rounded, 'color': AppColors.accent, 'tab': 1},
                  ];
                  final action = actions[index];
                  return GestureDetector(
                    onTap: () {
                      final state = context.findAncestorStateOfType<_HomeScreenState>();
                      if (state != null) {
                        // ignore: invalid_use_of_protected_member
                        state.setState(() => state._selectedIndex = action['tab'] as int);
                      }
                    },
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (action['color'] as Color).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              action['icon'] as IconData,
                              color: action['color'] as Color,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            action['label'] as String,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An active order on the dashboard: first item, count, total, time and
/// status, then accept / refuse (pending) or the next step.
class _DashboardOrderCard extends ConsumerWidget {
  const _DashboardOrderCard({required this.order});

  final dynamic order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typedOrder = order as Order;
    final statusColor = _statusColor(order.status);
    final isPending = order.status == OrderStatus.pending;

    // ── First-item thumbnail ──────────────────────────────────────────────
    final firstItem = typedOrder.items.isNotEmpty ? typedOrder.items.first : null;
    final imageUrl = firstItem?.imageUrl ?? '';

    // ── Order title: first item name + overflow count ─────────────────────
    final String orderTitle;
    if (firstItem == null) {
      orderTitle = '#${order.id.substring(0, 8).toUpperCase()}';
    } else {
      final extra = typedOrder.items.length - 1;
      orderTitle = extra > 0
          ? '${firstItem.displayName} + $extra item(s)'
          : firstItem.displayName;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
          // ── Item thumbnail (52×52) with shopping-bag fallback ──────────
          SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: statusColor.withOpacity(0.08),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _itemFallback(statusColor),
                    )
                  : _itemFallback(statusColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${typedOrder.items.length} item(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.total.toStringAsFixed(2)} DT',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.getStatusText(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
      if (isPending) ...[
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        _PendingOrderActions(
          order: order,
          onReject: () => _showRejectDialog(context, ref, order),
        ),
      ] else if (DashboardController.nextStatus(order.status) != null) ...[
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        AdvanceStatusButton(order: order, next: DashboardController.nextStatus(order.status)!),
      ],
    ],
  ),
);
  }

  /// Fallback widget shown when an item has no image or the URL fails to load.
  Widget _itemFallback(Color statusColor) {
    return Container(
      color: statusColor.withOpacity(0.12),
      child: Icon(Icons.shopping_bag_rounded, color: statusColor),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, dynamic order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: const Text('Êtes-vous sûr de vouloir refuser cette commande ? Cette action est irréversible.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(dashboardControllerProvider.notifier).reject(order.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sûr de refuser'),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'ready':
        return AppColors.success;
      case 'preparing':
        return AppColors.warning;
      case 'pending':
        return AppColors.primary;
      case 'confirmed':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Accept / refuse buttons for a pending order.
///
/// Previously the accept handler fired `updateOrderStatus` without awaiting it
/// and without catching anything. The repository *rethrows* on failure, so a
/// failed call became an unhandled async error: no spinner, no message, and the
/// row stayed "Pending" -- which is why tapping once looked like nothing
/// happened and partners tapped repeatedly. Now the call is awaited, the button
/// is disabled while it is in flight (so repeat taps can't queue duplicate
/// writes), and any error is surfaced.
class _PendingOrderActions extends ConsumerStatefulWidget {
  final dynamic order;
  final VoidCallback onReject;

  const _PendingOrderActions({required this.order, required this.onReject});

  @override
  ConsumerState<_PendingOrderActions> createState() =>
      _PendingOrderActionsState();
}

class _PendingOrderActionsState extends ConsumerState<_PendingOrderActions> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(audioAlertServiceProvider).stopAlert();
      // The native alarm notification is ongoing + FLAG_INSISTENT, so it keeps
      // ringing until explicitly cancelled; stopAlert() only silences the
      // in-app player.
      await PushService.instance.cancelOrderAlarm();
      await ref
          .read(partnerOrderRepositoryProvider)
          .updateOrderStatus(widget.order.id, OrderStatus.confirmed);

      // Re-fetch immediately rather than waiting for the realtime channel to
      // push the new row. Realtime is best-effort: if the websocket is down or
      // the event is dropped, waiting on it leaves the spinner running forever
      // -- which is exactly what made this button look stuck.
      ref.invalidate(partnerOrdersStreamProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Échec de l\'acceptation : $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    // Always clear the spinner on success. The card is normally rebuilt
    // without these buttons once the refreshed list arrives, but it must never
    // be left spinning if that rebuild doesn't happen.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : widget.onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                color: _busy ? AppColors.textSecondary : AppColors.error,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _busy ? null : _accept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.success.withOpacity(0.5),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Accepter'),
          ),
        ),
      ],
    );
  }
}
