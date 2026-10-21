import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order.dart';
import '../../providers/partner_orders_provider.dart';
import 'partner_orders_controller.dart';
import 'widgets/order_card.dart';

/// The orders tab: header, status filter, then the orders (or the empty
/// state).
class PartnerOrdersScreen extends ConsumerWidget {
  const PartnerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterStatus = ref.watch(partnerOrdersControllerProvider);
    final controller = ref.read(partnerOrdersControllerProvider.notifier);
    final ordersAsync = ref.watch(partnerOrdersStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const _OrdersHeader(),

          // Filter chips
          _FilterChips(
            selected: filterStatus,
            onSelect: (s) => controller.setFilter(s),
          ),

          // Orders list
          _OrdersList(
            ordersAsync: ordersAsync,
            filter: (orders) => controller.filter(orders),
          ),
        ],
      ),
    );
  }
}

// ── Sections, in screen order ────────────────────────────────────────────────

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: 120,
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
                  Text(
                    l.orders,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.manageOrdersRealtime,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    Widget chip(OrderStatus? status, String label) => _FilterChip(
        status: status, label: label, selected: selected, onSelect: onSelect);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(null, l.all),
              const SizedBox(width: 8),
              chip(OrderStatus.pending, l.filterNew),
              const SizedBox(width: 8),
              chip(OrderStatus.confirmed, l.confirmedFilter),
              const SizedBox(width: 8),
              chip(OrderStatus.preparing, l.preparingFilter),
              const SizedBox(width: 8),
              chip(OrderStatus.ready, l.ready),
              const SizedBox(width: 8),
              chip(OrderStatus.delivered, l.delivered),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.status,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final OrderStatus? status;
  final String label;
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == status;
    return GestureDetector(
      onTap: () => onSelect(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.ordersAsync, required this.filter});

  final AsyncValue<List<Order>> ordersAsync;
  final List<Order> Function(List<Order> orders) filter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ordersAsync.when(
      data: (orders) {
        final filtered = filter(orders);

        if (filtered.isEmpty) return const _EmptyOrders();

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderCard(order: filtered[index]),
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
            l.couldNotLoadOrders,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              l.noOrdersYet,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l.newOrdersAppearHere,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
