import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order watch: rings the new-order alarm even when the app is closed, without
/// depending on a push ever reaching the phone.
///
/// The FCM path (push-on-order-status -> CmandiliMessagingService) has three
/// things that can fail outside this app's control: the Edge Function not
/// finding the shop's partner, the server holding a stale device token, and
/// the phone maker's battery manager cancelling the wake-up of a closed app.
/// Any one of them and the shop hears nothing.
///
/// This is a second, independent path, the same idea the driver app already
/// uses for delivery offers: a small foreground service that stays alive after
/// the app is swiped away, asks the database every few seconds whether this
/// shop has a new pending order, and raises the SAME alarm notification (same
/// channel, same id) as the push would. Whichever path gets there first rings;
/// the other finds the alarm already up and does nothing.
///
/// ── Session ownership (read this before changing the token code) ───────────
/// Reading the shop's orders needs the partner's Supabase session. Supabase
/// rotates the refresh token on every refresh and treats an old one being
/// reused as theft: it revokes the whole session and the partner is logged
/// out. Two things refreshing independently would do exactly that. So:
///
///   * App alive   -> the app is the ONLY one that refreshes. This service
///                    only reads the session the app persisted; if it is about
///                    to expire while the app is backgrounded (supabase_flutter
///                    pauses auto-refresh then) it ASKS the app to refresh.
///   * App closed  -> nobody else is using the session, so the service
///                    refreshes it itself and persists the result in the exact
///                    slot supabase_flutter reads at next launch.
///
/// "Alive" is decided by a ping the app answers, never assumed.
class OrderWatchService {
  OrderWatchService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;
  static bool _mainAttached = false;

  /// Answers the service's pings and refresh requests. Call once from main().
  static void attachMain() {
    if (!Platform.isAndroid || _mainAttached) return;
    _mainAttached = true;
    WidgetsBinding.instance.addObserver(_ResumeObserver());
    _service.on(_evPing).listen((_) => _service.invoke(_evPong));
    _service.on(_evRefreshRequest).listen((_) async {
      try {
        // Persisted by supabase_flutter on the tokenRefreshed event; the
        // service then reads it from SharedPreferences.
        await Supabase.instance.client.auth.refreshSession();
      } catch (e) {
        debugPrint('OrderWatch: refresh on request failed: $e');
      }
    });
    // The service refreshed the session itself because this isolate did not
    // answer its ping in time (busy, or just starting). Adopt what it saved,
    // so this isolate never refreshes later with a token that has already
    // been rotated twice -- that is what Supabase punishes with a logout.
    _service.on(_evSessionChanged).listen((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final host = Uri.parse(prefs.getString(_kUrl) ?? '').host;
        final raw = prefs.getString('sb-${host.split('.').first}-auth-token');
        final current =
            Supabase.instance.client.auth.currentSession?.refreshToken;
        if (raw == null) return;
        final saved = (jsonDecode(raw) as Map<String, dynamic>)['refresh_token'];
        if (saved != null && saved != current) {
          await Supabase.instance.client.auth.recoverSession(raw);
        }
      } catch (e) {
        debugPrint('OrderWatch: adopting refreshed session failed: $e');
      }
    });
  }

  /// Starts watching [entityId]'s orders. Safe to call repeatedly.
  static Future<void> start({
    required String entityId,
    required String partnerType,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (!Platform.isAndroid) return;
    if (entityId.isEmpty || supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      // Saved before the permission check, so a later resume can retry.
      await prefs.setString(_kPartnerType, partnerType);
      await prefs.setString(_kUrl, supabaseUrl);
      await prefs.setString(_kAnonKey, supabaseAnonKey);
      await prefs.setString(_kEntityId, entityId);
      // Only supermarkets sit in supermarket_id; restaurants and every other
      // shop category ride restaurant_id (see PartnerOrderRepository).
      await prefs.setString(
        _kIdColumn,
        partnerType == 'supermarket' ? 'supermarket_id' : 'restaurant_id',
      );

      // A foreground service must post a notification; starting one without
      // the Android 13+ permission crashes the process. On a first install
      // PushService asks at about the same moment and this check could lose
      // the race -- so ask here too, and retry on every resume (below).
      var permission = await Permission.notification.status;
      if (!permission.isGranted) {
        permission = await Permission.notification.request();
      }
      if (!permission.isGranted) {
        debugPrint('OrderWatch: notifications not allowed, not starting yet');
        return;
      }

      await _configure();
      if (!await _service.isRunning()) {
        await _service.startService();
      }
    } catch (e) {
      debugPrint('OrderWatch: start failed: $e');
    }
  }

  /// Starts the watch again if a shop is saved but the service is not
  /// running: permission granted after the first attempt, or the service
  /// killed by the system. Called whenever the app comes to the front.
  static Future<void> _restartIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entityId = prefs.getString(_kEntityId);
      final partnerType = prefs.getString(_kPartnerType);
      final url = prefs.getString(_kUrl);
      final key = prefs.getString(_kAnonKey);
      if (entityId == null || partnerType == null || url == null || key == null) {
        return; // signed out, or never started
      }
      if (await _service.isRunning()) return;
      await start(
        entityId: entityId,
        partnerType: partnerType,
        supabaseUrl: url,
        supabaseAnonKey: key,
      );
    } catch (e) {
      debugPrint('OrderWatch: restart on resume failed: $e');
    }
  }

  /// Stops watching (logout). Clears the shop so a boot restart does nothing.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEntityId);
      if (await _service.isRunning()) _service.invoke(_evStop);
    } catch (e) {
      debugPrint('OrderWatch: stop failed: $e');
    }
  }

  static Future<void> _configure() async {
    if (_configured) return;

    // The channel must exist before the service posts to it, or Android
    // rejects the foreground notification and kills the process.
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kWatchChannelId,
          'Veille des commandes',
          description:
              'Garde l\'application prête à sonner pour une nouvelle commande',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ));

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: orderWatchOnStart,
        autoStart: false,
        // Back after a reboot, as long as a shop is still saved (see stop()).
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _kWatchChannelId,
        initialNotificationTitle: 'Amana Partner',
        initialNotificationContent: 'En attente de nouvelles commandes',
        foregroundServiceNotificationId: _kWatchNotifId,
        // Matches android:foregroundServiceType in AndroidManifest.xml.
        // specialUse rather than dataSync: Android 15 stops a dataSync
        // service after 6 hours a day, and a shop stays open longer.
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    _configured = true;
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OrderWatchService._restartIfNeeded();
    }
  }
}

// ── Shared constants ─────────────────────────────────────────────────────────

const _kWatchChannelId = 'cmandili_partner_watch';
const _kWatchNotifId = 4242;

// Same alarm channel and notification id as push_service.dart and
// CmandiliMessagingService.kt, so the two paths update ONE notification.
const _kAlarmChannelId = 'cmandili_orders_urgent_4';
const _kAlarmChannelName = 'Urgent Order updates';
const _kAlarmChannelDesc = 'Urgent alerts for new incoming orders';
const _kAlarmNotifId = 42;

const _kUrl = 'order_watch_supabase_url';
const _kAnonKey = 'order_watch_supabase_key';
const _kEntityId = 'order_watch_entity_id';
const _kIdColumn = 'order_watch_id_column';
const _kPartnerType = 'order_watch_partner_type';

const _evPing = 'order_watch_ping';
const _evPong = 'order_watch_pong';
const _evRefreshRequest = 'order_watch_refresh_request';
const _evSessionChanged = 'order_watch_session_changed';
const _evStop = 'order_watch_stop';

/// How often the database is asked for pending orders.
const _kPollEvery = Duration(seconds: 8);

/// An order already this old when the service starts is one the shop has
/// seen (or that already rang); only fresher ones ring on the first check.
const _kFreshOnStart = Duration(minutes: 3);

// ── Service isolate ──────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void orderWatchOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final url = prefs.getString(_kUrl) ?? '';
  final anonKey = prefs.getString(_kAnonKey) ?? '';
  if (url.isEmpty || anonKey.isEmpty || prefs.getString(_kEntityId) == null) {
    service.stopSelf();
    return;
  }
  // The slot supabase_flutter persists the session in (supabase.dart).
  final sessionKey = 'sb-${Uri.parse(url).host.split('.').first}-auth-token';

  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  final android = local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  // Normally already created natively (Application.kt); idempotent.
  await android?.createNotificationChannel(AndroidNotificationChannel(
    _kAlarmChannelId,
    _kAlarmChannelName,
    description: _kAlarmChannelDesc,
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('new_order'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 300, 700, 300, 700]),
  ));

  // ── Is the app (main isolate) alive? ───────────────────────────────────────
  var lastPong = DateTime.fromMillisecondsSinceEpoch(0);
  service.on(_evPong).listen((_) => lastPong = DateTime.now());

  Future<bool> appAlive() async {
    final asked = DateTime.now();
    service.invoke(_evPing);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (lastPong.isAfter(asked)) return true;
    }
    return false;
  }

  // ── Session ────────────────────────────────────────────────────────────────

  int secondsLeft(String accessToken) => jwtSecondsLeft(accessToken);

  Future<Map<String, dynamic>?> readSession() async {
    await prefs.reload(); // pick up what the app isolate wrote
    final raw = prefs.getString(sessionKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// A valid access token, or null when there is none to be had right now.
  /// See "Session ownership" at the top of this file.
  Future<String?> accessToken() async {
    var session = await readSession();
    var token = session?['access_token'] as String?;
    if (token == null) return null; // logged out
    if (secondsLeft(token) > 90) return token;

    if (await appAlive()) {
      // The app owns the session: ask it to refresh, then read the result.
      service.invoke(_evRefreshRequest);
      await Future<void>.delayed(const Duration(seconds: 4));
      session = await readSession();
      token = session?['access_token'] as String?;
      if (token == null) return null;
      return secondsLeft(token) > 5 ? token : null;
    }

    // App closed: this service is the only user of the session.
    final refreshToken = session?['refresh_token'] as String?;
    if (refreshToken == null) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$url/auth/v1/token?grant_type=refresh_token'),
            headers: {
              'apikey': anonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final fresh = jsonDecode(resp.body) as Map<String, dynamic>;
        final access = fresh['access_token'] as String?;
        if (access != null && fresh['user'] != null) {
          // Same shape as Session.toJson(), which is what the app reads back.
          await prefs.setString(sessionKey, jsonEncode(fresh));
          // In case the app is alive after all and just missed the ping.
          service.invoke(_evSessionChanged);
          return access;
        }
      } else {
        debugPrint('OrderWatch: refresh refused ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('OrderWatch: refresh failed: $e'); // offline: retry next tick
    }
    // The app may have started and refreshed in the meantime.
    session = await readSession();
    token = session?['access_token'] as String?;
    return (token != null && secondsLeft(token) > 5) ? token : null;
  }

  // ── Alarm ──────────────────────────────────────────────────────────────────

  Future<bool> alarmShowing() async {
    try {
      final active = await android?.getActiveNotifications() ?? const [];
      return active.any((n) => n.id == _kAlarmNotifId);
    } catch (_) {
      return false;
    }
  }

  Future<void> ring(String orderId) => local.show(
        _kAlarmNotifId,
        '🔔 Nouvelle commande !',
        'Vous avez une commande en attente.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kAlarmChannelId,
            _kAlarmChannelName,
            channelDescription: _kAlarmChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('new_order'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 300, 700, 300, 700]),
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: loops
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.call,
            ongoing: true,
            autoCancel: false,
          ),
        ),
        payload: orderId,
      );

  // ── Poll ───────────────────────────────────────────────────────────────────

  final tracker = PendingOrderTracker();
  var busy = false;

  Future<void> check() async {
    if (busy) return;
    busy = true;
    try {
      await prefs.reload();
      final entityId = prefs.getString(_kEntityId);
      final idColumn = prefs.getString(_kIdColumn) ?? 'restaurant_id';
      if (entityId == null) {
        service.stopSelf(); // logged out
        return;
      }

      final token = await accessToken();
      if (token == null) return;

      final resp = await http.get(
        Uri.parse(
          '$url/rest/v1/orders'
          '?select=id,created_at'
          '&$idColumn=eq.$entityId'
          '&status=eq.pending'
          '&order=created_at.desc&limit=20',
        ),
        headers: {'apikey': anonKey, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('OrderWatch: poll ${resp.statusCode}');
        return;
      }

      final rows = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      final decision = tracker.update(
        [
          for (final r in rows)
            (
              id: r['id'] as String,
              createdAt: DateTime.tryParse('${r['created_at']}'),
            ),
        ],
        // The push path may already be ringing: one alarm is enough, and
        // re-posting it would restart the sound.
        alarmShowing: await alarmShowing(),
      );
      if (decision.ringFor != null) await ring(decision.ringFor!);
      if (decision.cancel) await local.cancel(_kAlarmNotifId);
    } catch (e) {
      debugPrint('OrderWatch: check failed: $e'); // offline etc: next tick
    } finally {
      busy = false;
    }
  }

  final timer = Timer.periodic(_kPollEvery, (_) => check());
  service.on(_evStop).listen((_) {
    timer.cancel();
    service.stopSelf();
  });
  unawaited(check());
}

// ── Pure logic (unit-tested in test/order_watch_logic_test.dart) ────────────

/// Seconds until [accessToken] (a JWT) expires; negative once expired, -1 if
/// it cannot be read.
@visibleForTesting
int jwtSecondsLeft(String accessToken, {DateTime? now}) {
  try {
    final payload = accessToken.split('.')[1];
    final json = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    ) as Map<String, dynamic>;
    final exp = (json['exp'] as num).toInt();
    return exp - (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return -1;
  }
}

/// What to do after one look at the shop's pending orders.
class WatchDecision {
  /// Ring the alarm for this order (null = do not ring).
  final String? ringFor;

  /// Stop the alarm this watch raised: its order is no longer pending.
  final bool cancel;

  const WatchDecision({this.ringFor, this.cancel = false});
}

/// Decides when the order watch rings and when it stops ringing.
///
///  * First look after start-up: orders older than [freshOnStart] were
///    already seen (or already rang), so they do not ring again.
///  * A new pending order rings once -- unless an alarm is already showing
///    (the push got there first); it is then just remembered.
///  * When the order this watch rang for leaves "pending" (accepted, refused
///    or cancelled, maybe from another phone): if another order arrived while
///    that alarm was ringing, it rings for that one -- otherwise one alarm
///    for two orders would go quiet with the second never seen. Only when
///    nothing is waiting is the alarm cancelled. An alarm raised by the push
///    path is left for the app to clear.
@visibleForTesting
class PendingOrderTracker {
  PendingOrderTracker({this.freshOnStart = _kFreshOnStart});

  final Duration freshOnStart;
  final _known = <String>{};

  /// New orders that arrived while an alarm was already ringing.
  final _absorbed = <String>{};
  String? _rangFor;
  bool _firstLook = true;

  WatchDecision update(
    List<({String id, DateTime? createdAt})> pending, {
    required bool alarmShowing,
    DateTime? now,
  }) {
    final ids = {for (final p in pending) p.id};

    if (_firstLook) {
      _firstLook = false;
      final cutoff = (now ?? DateTime.now()).toUtc().subtract(freshOnStart);
      for (final p in pending) {
        final created = p.createdAt?.toUtc();
        if (created == null || created.isBefore(cutoff)) _known.add(p.id);
      }
    }

    String? ringFor;
    final fresh = ids.difference(_known);
    if (fresh.isNotEmpty) {
      _known.addAll(fresh);
      if (!alarmShowing) {
        ringFor = fresh.first;
        _rangFor = ringFor;
        _absorbed.addAll(fresh.skip(1));
      } else {
        _absorbed.addAll(fresh);
      }
    }
    _absorbed.removeWhere((id) => !ids.contains(id));

    var cancel = false;
    if (ringFor == null && _rangFor != null && !ids.contains(_rangFor)) {
      if (_absorbed.isNotEmpty) {
        ringFor = _absorbed.first; // the one nobody has heard about yet
        _absorbed.remove(ringFor);
        _rangFor = ringFor;
      } else {
        _rangFor = null;
        cancel = true;
      }
    }
    _known.removeWhere((id) => !ids.contains(id));
    return WatchDecision(ringFor: ringFor, cancel: cancel);
  }
}
