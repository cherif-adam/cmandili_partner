import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../partner_onboarding_screen.dart';
import 'not_a_partner_controller.dart';

/// Ce compte est connecté, mais ce n'est pas un compte partenaire.
///
/// L'application ouvrait directement l'écran de configuration dans ce cas, et
/// le premier nom saisi créait une boutique. C'est exactement ce qui est
/// arrivé le 30/09 : le compte administrateur, dont la boutique venait d'être
/// transférée, était encore connecté dans `flutter run` ; l'application a vu
/// « connecté, pas de ligne partners », en a conclu « nouveau partenaire », et
/// a créé une seconde boutique sur un nom tapé pour en retrouver une autre.
///
/// Un compte sans boutique n'est pas forcément un partenaire qui débute : ce
/// peut être un administrateur, un client, un livreur — ou un partenaire qui
/// s'est trompé de compte. L'application ne peut pas trancher, donc elle
/// demande, au lieu d'ouvrir un formulaire qui écrit en base au premier
/// bouton.
///
/// Top to bottom: _Explanation (icon, title, text, the signed-in e-mail),
/// then _Actions (sign out, create a shop). UI only: signing out goes
/// through [NotAPartnerController].
class NotAPartnerScreen extends ConsumerWidget {
  const NotAPartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notAPartnerControllerProvider);
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Explanation(email: email),
                const SizedBox(height: 28),
                _Actions(
                  onSignOut: ref.read(notAPartnerControllerProvider.notifier).signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _Explanation extends StatelessWidget {
  const _Explanation({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.storefront_outlined,
            size: 72, color: AppColors.textLight),
        const SizedBox(height: 20),
        Text(
          l.notAPartnerTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          l.notAPartnerBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.textLight.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    email,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Se déconnecter d'abord : c'est le geste attendu neuf fois sur
        // dix, quelqu'un qui s'est connecté avec le mauvais compte.
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(l.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Créer une boutique reste possible, mais c'est un choix
        // explicite, pas la conséquence d'un écran qui s'ouvre tout
        // seul.
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PartnerOnboardingScreen(),
              ),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: Text(l.createShop),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
