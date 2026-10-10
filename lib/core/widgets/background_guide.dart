import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// One-time guide for phones that stop apps in the background.
///
/// Xiaomi, Oppo, Vivo, Huawei, Tecno and the like add their own switch on
/// top of Android's: unless "Autostart" is on for an app, the phone kills
/// its services once it is closed and never wakes it for a push. On those
/// phones no amount of code makes a new-order alarm ring with the app
/// closed -- the owner has to flip that switch, and nothing in the phone
/// tells them so. This does: it explains in two lines and opens the right
/// screen.
///
/// Shown only on those makers, until the owner taps "Done"; "Later" asks
/// again the next day.
class BackgroundGuide {
  BackgroundGuide._();

  // Same channel MainActivity.kt already answers on.
  static const _channel = MethodChannel('com.cmandili.partner/notifications');
  static const _doneKey = 'bg_guide_done';
  static const _snoozeKey = 'bg_guide_snoozed_until';

  /// Makers known to kill background apps unless told otherwise.
  static const _makers = [
    'xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'oneplus', 'vivo', 'iqoo',
    'huawei', 'honor', 'tecno', 'infinix', 'itel', 'transsion', 'samsung',
    'meizu', 'asus', 'lenovo',
  ];

  static bool _showing = false;

  /// Shows the guide if this phone needs it and the owner has not dealt with
  /// it yet. Safe to call on every start; never throws.
  static Future<void> maybeShow(BuildContext context) async {
    if (!Platform.isAndroid || _showing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) == true) return;
      final snoozedUntil = prefs.getInt(_snoozeKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < snoozedUntil) return;

      final maker =
          ((await _channel.invokeMethod<String>('getManufacturer')) ?? '')
              .toLowerCase();
      if (!_makers.any(maker.contains)) {
        // A phone that leaves background apps alone: nothing to ask.
        await prefs.setBool(_doneKey, true);
        return;
      }
      if (!context.mounted) return;

      _showing = true;
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => const _GuideDialog(),
      );
      _showing = false;

      if (result == 'done') {
        await prefs.setBool(_doneKey, true);
      } else {
        // "Later", or dismissed: ask again tomorrow rather than on every
        // launch, and rather than never.
        await prefs.setInt(
          _snoozeKey,
          DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      _showing = false;
      debugPrint('BackgroundGuide: $e');
    }
  }

  static Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod<String>('openBackgroundSettings');
    } catch (e) {
      debugPrint('BackgroundGuide: could not open settings: $e');
    }
  }
}

class _GuideDialog extends StatelessWidget {
  const _GuideDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.bgGuideTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bgGuideBody),
          const SizedBox(height: 14),
          _step('1', l.bgGuideStep1),
          const SizedBox(height: 8),
          _step('2', l.bgGuideStep2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Stays open: the owner comes back from the settings screen
              // and confirms with "Done".
              onPressed: BackgroundGuide._openSettings,
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(l.bgGuideOpen),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'later'),
          child: Text(l.bgGuideLater),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'done'),
          child: Text(
            l.bgGuideDone,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _step(String n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            n,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
