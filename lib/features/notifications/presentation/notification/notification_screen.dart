import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/notification.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import 'notification_controller.dart';
import 'widgets/empty_notifications.dart';
import 'widgets/notification_card.dart';

/// "Notifications": "Tout marquer comme lu" in the app bar while some are
/// unread, then EmptyNotifications or the list grouped by day
/// (_NotificationGroups).
///
/// UI only: the list, its grouping and the actions live in
/// [NotificationController].
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final notifications = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    // Group notifications by date
    final groupedNotifications = controller.groupByDay();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        actions: [
          if (controller.hasUnread)
            TextButton(
              onPressed: controller.markAllAsRead,
              child: Text(
                AppLocalizations.of(context)!.markAllRead,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? EmptyNotifications(screenWidth: screenWidth, screenHeight: screenHeight)
          : _NotificationGroups(
              groups: groupedNotifications,
              onOpen: controller.open,
              onDelete: controller.delete,
            ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One header per day, its notifications under it.
class _NotificationGroups extends StatelessWidget {
  const _NotificationGroups({
    required this.groups,
    required this.onOpen,
    required this.onDelete,
  });

  final Map<String, List<AppNotification>> groups;
  final void Function(AppNotification) onOpen;
  final void Function(AppNotification) onDelete;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    return ListView.builder(
      padding: EdgeInsets.all(screenWidth * 0.05),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        final dateLabel = entry.key;
        final notificationList = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.015,
                horizontal: screenWidth * 0.02,
              ),
              child: Text(
                dateLabel,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...notificationList.map((notification) {
              return NotificationCard(
                notification: notification,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                onTap: () => onOpen(notification),
                onDismissed: () => onDelete(notification),
              );
            }),
          ],
        );
      },
    );
  }
}
