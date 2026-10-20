import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/notification.dart';
import '../../providers/notification_provider.dart';

final notificationControllerProvider =
    NotifierProvider.autoDispose<NotificationController, List<AppNotification>>(
        NotificationController.new);

/// The notifications screen's logic: the list (from [notificationProvider]),
/// its grouping by day and the three user actions.
class NotificationController extends AutoDisposeNotifier<List<AppNotification>> {
  // ── State ─────────────────────────────────────────────────────────────────

  @override
  List<AppNotification> build() => ref.watch(notificationProvider);

  bool get hasUnread => state.any((n) => !n.isRead);

  // ── User actions ──────────────────────────────────────────────────────────

  void markAllAsRead() =>
      ref.read(notificationProvider.notifier).markAllAsRead();

  /// Tapping a card marks it read (nothing to do when it already is).
  void open(AppNotification notification) {
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }
  }

  void delete(AppNotification notification) =>
      ref.read(notificationProvider.notifier).deleteNotification(notification.id);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Today, Yesterday, the weekday for this week, else the date — in the
  /// order the notifications come.
  Map<String, List<AppNotification>> groupByDay() {
    final Map<String, List<AppNotification>> grouped = {};
    final now = DateTime.now();

    for (final notification in state) {
      String dateLabel;
      final difference = now.difference(notification.timestamp);

      if (difference.inDays == 0) {
        dateLabel = 'Today';
      } else if (difference.inDays == 1) {
        dateLabel = 'Yesterday';
      } else if (difference.inDays < 7) {
        dateLabel = DateFormat('EEEE').format(notification.timestamp);
      } else {
        dateLabel = DateFormat('MMM dd, yyyy').format(notification.timestamp);
      }

      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }
      grouped[dateLabel]!.add(notification);
    }

    return grouped;
  }
}
