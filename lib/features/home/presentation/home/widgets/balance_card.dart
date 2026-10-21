import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../profile/providers/partner_wallet_provider.dart';
import '../home_controller.dart';

/// Prepaid balance ("solde") on the dashboard.
///
/// The owner loads credit onto each restaurant; every delivered cash order
/// deducts the platform's commission from it, and the restaurant is blocked
/// from receiving new orders once it reaches zero. Surfacing it here means a
/// partner sees it dropping before they get cut off.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(partnerWalletProvider);
    final rateAsync = ref.watch(commissionRateProvider);

    return balanceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (balance) {
        final value = balance ?? 0;
        final blocked = value <= 0;
        final low = !blocked && value < 20;
        final accent = blocked
            ? AppColors.error
            : low
                ? AppColors.warning
                : AppColors.success;
        final ratePercent =
            ((rateAsync.value ?? 0.10) * 100).toStringAsFixed(0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Solde',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${value.toStringAsFixed(2)} DT',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$ratePercent % / commande',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (blocked || low) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        blocked
                            ? Icons.block_rounded
                            : Icons.warning_amber_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          blocked
                              ? 'Solde épuisé — vous ne recevez plus de commandes. '
                                  'Contactez l\'administrateur pour recharger.'
                              : 'Solde faible — pensez à recharger pour continuer '
                                  'à recevoir des commandes.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: accent, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
