import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Channel id must match com.google.firebase.messaging.default_notification_channel_id
// in AndroidManifest.xml so background `notification` payloads land here too.
const String _kAndroidChannelId   = 'cmandili_orders';
const String _kAndroidChannelName = 'Order updates';
const String _kAndroidChannelDesc = 'Notifications about your orders';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final type = message.data['type'] as String?;
  if (type == 'new_order') {
    final local = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await local.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    final title = message.data['title'] as String? ?? 'Nouvelle commande !';
    final body = message.data['body'] as String? ?? 'Vous avez une commande en attente.';
    
    local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'cmandili_orders_urgent_2',
          'Urgent Order updates',
          channelDescription: 'Urgent notifications for new orders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('new_order'),
          additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: true,
          sound: 'new_order.wav', // Important: on iOS, needs to be .wav or .caf
        ),
      ),
    );
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Pre-create the Android channel so the OS has it ready when background
    // pushes arrive — otherwise the first push after install is silently
    // dropped on Android 8+.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kAndroidChannelId,
          _kAndroidChannelName,
          description: _kAndroidChannelDesc,
          importance: Importance.high,
        ));

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          'cmandili_orders_urgent_2',
          'Urgent Order updates',
          description: 'Urgent notifications for new orders',
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('new_order'),
          additionalFlags: Int32List.fromList([4]),
        ));

    // Show heads-up alerts even while the app is in the foreground (iOS).
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _registerToken();
    _fcm.onTokenRefresh.listen((_) => _registerToken());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _registerToken();
      }
    });
  }

  Future<void> _registerToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      }, onConflict: 'token');
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final title = message.notification?.title ?? message.data['title'] as String?;
    final body  = message.notification?.body  ?? message.data['body']  as String?;
    if (title == null && body == null) return;

    final isUrgent = type == 'new_order';

    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isUrgent ? 'cmandili_orders_urgent_2' : _kAndroidChannelId,
          isUrgent ? 'Urgent Order updates' : _kAndroidChannelName,
          channelDescription: _kAndroidChannelDesc,
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.high : Priority.high,
          playSound: true,
          sound: isUrgent ? const RawResourceAndroidNotificationSound('new_order') : null,
          additionalFlags: isUrgent ? Int32List.fromList([4]) : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: isUrgent ? 'new_order.wav' : null,
        ),
      ),
    );
  }
}
