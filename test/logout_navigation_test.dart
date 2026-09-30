import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pourquoi une connexion reussie laissait l'utilisateur sur l'ecran de
/// connexion jusqu'au redemarrage de l'app.
///
/// main.dart fait basculer sa racine entre l'ecran de connexion et l'accueil
/// quand la session change, et cette bascule FONCTIONNE. Ce qui la cassait,
/// c'est Profil > Deconnexion : il se deconnectait bien, mais empilait
/// ensuite un AuthScreen avec pushAndRemoveUntil(... false).
/// Cela supprimait la route racine et laissait un ecran de connexion empile
/// par-dessus. La connexion suivante faisait bien passer la racine a
/// l'accueil, mais plus rien ne l'affichait.
///
/// Le correctif : revenir a la route racine, puis se deconnecter pour de
/// vrai -- la racine devient elle-meme l'ecran de connexion, puis l'accueil.
void main() {
  Widget app(ValueListenable<bool> signedIn) {
    return ValueListenableBuilder<bool>(
      valueListenable: signedIn,
      builder: (context, value, _) => MaterialApp(
        home: value ? const _Screen('HOME') : const _Screen('AUTH'),
      ),
    );
  }

  testWidgets('BUG: l ancienne deconnexion empile un ecran de connexion',
      (tester) async {
    final signedIn = ValueNotifier<bool>(true);
    await tester.pumpWidget(app(signedIn));
    expect(find.text('HOME'), findsOneWidget);

    // L'ancien bouton Deconnexion.
    tester.state<NavigatorState>(find.byType(Navigator)).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _Screen('AUTH')),
          (route) => false,
        );
    await tester.pumpAndSettle();
    expect(find.text('AUTH'), findsOneWidget);

    // L'utilisateur se reconnecte.
    signedIn.value = false;
    signedIn.value = true;
    await tester.pumpAndSettle();

    expect(find.text('AUTH'), findsOneWidget,
        reason: 'l ecran de connexion empile reste ce qui est affiche');
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('CORRIGE: revenir a la racine et se deconnecter vraiment',
      (tester) async {
    final signedIn = ValueNotifier<bool>(true);
    await tester.pumpWidget(app(signedIn));

    // Le nouveau bouton : popUntil(isFirst) + signOut().
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .popUntil((route) => route.isFirst);
    signedIn.value = false;
    await tester.pumpAndSettle();
    expect(find.text('AUTH'), findsOneWidget);

    signedIn.value = true;
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('AUTH'), findsNothing);
  });
}

class _Screen extends StatelessWidget {
  final String label;
  const _Screen(this.label);

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}
