import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';

import '../providers/account_deletion_provider.dart';
import 'widgets/deletion_blockers_card.dart';
import 'widgets/deletion_confirm_form.dart';
import 'widgets/deletion_info_card.dart';
import 'widgets/deletion_load_error.dart';

/// « Supprimer mon compte » (exigence Google Play et Apple).
///
/// L'écran explique d'abord ce qui part et ce qui reste, vérifie ensuite ce
/// qui bloque (commande en cours, solde à régler, litige ouvert). S'il y a un
/// blocage, il dit quoi faire et ne propose pas la suppression ; sinon, il
/// demande le mot de confirmation et une ré-authentification. La suppression
/// elle-même se fait côté serveur.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final blockers = ref.watch(accountDeletionBlockersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccount)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(width * 0.05),
          children: [
            const DeletionInfoCard(),
            SizedBox(height: width * 0.06),
            blockers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => DeletionLoadError(
                onRetry: () => ref.invalidate(accountDeletionBlockersProvider),
              ),
              data: (list) => list.isEmpty
                  ? DeletionConfirmForm(
                      onBlockedLate: () => ref.invalidate(accountDeletionBlockersProvider),
                    )
                  : DeletionBlockersCard(blockers: list),
            ),
          ],
        ),
      ),
    );
  }
}
