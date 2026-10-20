import 'package:flutter/material.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';

/// Big bell and "Aucune notification" when the list is empty.
class EmptyNotifications extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const EmptyNotifications({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: screenWidth * 0.2,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            AppLocalizations.of(context)!.noNotifications,
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            AppLocalizations.of(context)!.notificationsWillAppearHere,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: screenWidth * 0.04,
            ),
          ),
        ],
      ),
    );
  }
}
