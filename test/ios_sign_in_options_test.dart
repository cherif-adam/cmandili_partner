import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import 'package:cmandili_partner/features/auth/presentation/auth/auth_screen.dart';

/// Apple rejects an iPhone app that offers Google sign-in without Sign in
/// with Apple (App Store guideline 4.8). This app has no Apple sign-in, so
/// on iPhone the login screen offers e-mail and password only; Android keeps
/// Google.
Future<void> pumpAuth(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AuthScreen(),
    ),
  ));
  // No pumpAndSettle: the background animation repeats forever.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  testWidgets('iPhone: no Google button', (tester) async {
    await pumpAuth(tester);
    expect(find.byKey(const Key('auth_google')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: Google button kept', (tester) async {
    await pumpAuth(tester);
    expect(find.byKey(const Key('auth_google')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
