import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Puts the phone's ALARM volume at maximum, silently (no volume slider on
/// screen).
///
/// The order alarm plays on the alarm stream (USAGE_ALARM), which is what
/// lets it ring through silent mode and Do Not Disturb -- but that stream has
/// its own volume, and on a phone where it was left low the alarm was barely
/// audible however loud the sound file is. An order nobody hears costs a
/// sale, so the alarm does not trust that setting: it raises it every time
/// it rings. (The level stays raised afterwards; it is the same slider as the
/// phone's alarm clock.)
///
/// Safe from any isolate: the plugin only needs the application context, so
/// it works in the FCM background handler and in the foreground services.
/// Never throws.
Future<void> maxAlarmVolume() async {
  if (!Platform.isAndroid) return;
  try {
    await FlutterVolumeController.updateShowSystemUI(false);
    await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
  } catch (e) {
    debugPrint('maxAlarmVolume failed: $e');
  }
}
