import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/providers/localization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/supabase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/push/push_service.dart';
import 'core/push/notification_navigation.dart';
import 'core/services/order_watch_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv MUST resolve first — SupabaseConfig reads from it. Then run
  // Supabase + Firebase in parallel.
  //
  // Google Maps needs no runtime token call: the key is read from the native
  // manifest/plist at process start, so there is no equivalent of Mapbox's
  // MapboxOptions.setAccessToken here.
  await dotenv.load(fileName: '.env');

  await Future.wait([
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .catchError((_) => Firebase.app()),
  ]);

  // MUST be registered before runApp(). Firebase spawns a separate Dart
  // isolate for background/terminated FCM messages and calls this handler
  // directly via the @pragma('vm:entry-point') annotation. If it is
  // registered after runApp() (e.g. in addPostFrameCallback), Android never
  // wires it up and data-only alarm messages are silently dropped.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));

  // Defer the rest of push init (token fetch + Supabase upsert + foreground
  // listener) off the critical path so it doesn't stall first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.initialize().catchError((e) {
      debugPrint('PushService.initialize top-level failure: $e');
    });
    // Wire notification-tap deep-linking and drain any cold-start tap that
    // launched the app onto a specific order.
    NotificationNavigation.instance.initialize();
    // Lets the order-watch service ask this isolate whether the app is alive
    // and to refresh the session for it (see OrderWatchService).
    OrderWatchService.attachMain();
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localizationProvider);
    final themeMode = ref.watch(themeProvider);

    // Order watch: rings for new orders even with the app closed, without
    // depending on a push reaching the phone. Runs for as long as a partner
    // with a shop is signed in; stops when they sign out.
    ref.listen(partnerProfileProvider, (_, next) {
      final profile = next.valueOrNull;
      if (profile != null && profile.entityId.isNotEmpty) {
        OrderWatchService.start(
          entityId: profile.entityId,
          partnerType: profile.partnerType,
          supabaseUrl: SupabaseConfig.url,
          supabaseAnonKey: SupabaseConfig.anonKey,
        );
      }
    });
    ref.listen(authStateProvider, (prev, next) {
      // Only a real sign-out (there WAS a user, now there is none) -- not the
      // loading state at start-up, which would switch the watch off by itself.
      if (prev?.valueOrNull != null && next.hasValue && next.value == null) {
        OrderWatchService.stop();
      }
    });

    return MaterialApp(
      title: 'Cmandili Partner',
      navigatorKey: NotificationNavigation.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
      ],
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const AuthScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const AuthScreen(),
      ),
    );
  }
}
