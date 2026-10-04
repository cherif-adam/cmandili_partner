import 'dart:convert';

import 'package:cmandili_partner/core/services/order_watch_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scenarios for the order watch's decisions (order_watch_service.dart):
/// when it rings, when it stays quiet, and when it stops ringing.
void main() {
  final now = DateTime.utc(2026, 10, 3, 12, 0);
  ({String id, DateTime? createdAt}) order(String id, {int minutesAgo = 0}) =>
      (id: id, createdAt: now.subtract(Duration(minutes: minutesAgo)));

  group('jwtSecondsLeft', () {
    String jwt(int exp) {
      String part(Map<String, dynamic> m) =>
          base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
    }

    test('seconds until expiry', () {
      final exp = now.millisecondsSinceEpoch ~/ 1000 + 100;
      expect(jwtSecondsLeft(jwt(exp), now: now), 100);
    });

    test('negative once expired', () {
      final exp = now.millisecondsSinceEpoch ~/ 1000 - 30;
      expect(jwtSecondsLeft(jwt(exp), now: now), -30);
    });

    test('unreadable token counts as expired', () {
      expect(jwtSecondsLeft('not-a-jwt', now: now), -1);
    });
  });

  group('PendingOrderTracker', () {
    test('at start-up, an old pending order does not ring, a fresh one does',
        () {
      final t = PendingOrderTracker();
      final d = t.update(
        [order('old', minutesAgo: 10), order('fresh', minutesAgo: 1)],
        alarmShowing: false,
        now: now,
      );
      expect(d.ringFor, 'fresh');
    });

    test('a new order rings exactly once', () {
      final t = PendingOrderTracker();
      expect(t.update([], alarmShowing: false, now: now).ringFor, isNull);

      final first = t.update([order('A')], alarmShowing: false, now: now);
      expect(first.ringFor, 'A');

      // Same order on the next look (alarm still up): nothing new.
      final again = t.update([order('A')], alarmShowing: true, now: now);
      expect(again.ringFor, isNull);
      expect(again.cancel, isFalse);
    });

    test('push already ringing: remembered, not re-rung, not cancelled by us',
        () {
      final t = PendingOrderTracker();
      t.update([], alarmShowing: false, now: now);

      final d = t.update([order('A')], alarmShowing: true, now: now);
      expect(d.ringFor, isNull, reason: 'one alarm is enough');

      // Accepted: the push's alarm is the app's to clear, not ours.
      final after = t.update([], alarmShowing: true, now: now);
      expect(after.cancel, isFalse);
    });

    test('our alarm stops once its order is accepted or refused', () {
      final t = PendingOrderTracker();
      t.update([], alarmShowing: false, now: now);
      t.update([order('A')], alarmShowing: false, now: now);

      final d = t.update([], alarmShowing: true, now: now);
      expect(d.cancel, isTrue);
    });

    test('second order during our alarm: rings for it when the first is done',
        () {
      final t = PendingOrderTracker();
      t.update([], alarmShowing: false, now: now);
      expect(t.update([order('A')], alarmShowing: false, now: now).ringFor, 'A');

      // B arrives while A's alarm is ringing.
      expect(
        t.update([order('A'), order('B')], alarmShowing: true, now: now).ringFor,
        isNull,
      );

      // A accepted: B must not go silent.
      final afterA = t.update([order('B')], alarmShowing: true, now: now);
      expect(afterA.ringFor, 'B');
      expect(afterA.cancel, isFalse);

      // B accepted: now the alarm can stop.
      final afterB = t.update([], alarmShowing: true, now: now);
      expect(afterB.cancel, isTrue);
    });

    test('two new orders at once: one alarm, then the other', () {
      final t = PendingOrderTracker();
      t.update([], alarmShowing: false, now: now);
      final d = t.update([order('A'), order('B')], alarmShowing: false, now: now);
      expect(d.ringFor, isNotNull);
      final other = d.ringFor == 'A' ? 'B' : 'A';

      final next = t.update([order(other)], alarmShowing: true, now: now);
      expect(next.ringFor, other);
    });

    test('order cancelled by the customer before anyone answered', () {
      final t = PendingOrderTracker();
      t.update([], alarmShowing: false, now: now);
      t.update([order('A')], alarmShowing: false, now: now);
      // Customer cancels: no longer pending -> stop ringing.
      expect(t.update([], alarmShowing: true, now: now).cancel, isTrue);
      // And a later order still rings normally.
      expect(t.update([order('C')], alarmShowing: false, now: now).ringFor, 'C');
    });
  });
}
