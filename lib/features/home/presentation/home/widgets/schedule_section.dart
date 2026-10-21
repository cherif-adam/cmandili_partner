import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../home_controller.dart';

/// Default opening hours: the auto-close switch, then (when on) the
/// opening and closing times, each opening the time picker.
class ScheduleSection extends ConsumerStatefulWidget {
  final dynamic profile; // PartnerProfile
  const ScheduleSection({super.key, required this.profile});

  @override
  ConsumerState<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends ConsumerState<ScheduleSection> {
  bool _saving = false;
  String? _savedMsg;

  Future<void> _pickTime({required bool isClosing}) async {
    final schedule = ref.read(scheduleControllerProvider);
    final initial = isClosing ? (schedule.closingTime ?? TimeOfDay.now()) : (schedule.openingTime ?? TimeOfDay.now());
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (!mounted || picked == null) return;
    setState(() => _saving = true);
    try {
      if (isClosing) {
        await ref.read(scheduleControllerProvider.notifier).setClosingTime(picked, widget.profile.entityId as String, widget.profile.partnerType as String);
      } else {
        await ref.read(scheduleControllerProvider.notifier).setOpeningTime(picked, widget.profile.entityId as String, widget.profile.partnerType as String);
      }
      if (mounted) {
        setState(() { _saving = false; _savedMsg = AppLocalizations.of(context)!.scheduleSaved; });
        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _savedMsg = null); });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleControllerProvider);
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + enable switch
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.defaultHours,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(l.enableAutoClose,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: schedule.autoCloseEnabled,
                activeColor: AppColors.primary,
                onChanged: (v) => ref.read(scheduleControllerProvider.notifier)
                    .setAutoClose(v, widget.profile.entityId as String, widget.profile.partnerType as String),
              ),
            ],
          ),

          // Time rows — only shown when auto-close is enabled
          if (schedule.autoCloseEnabled) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildTimeRow(
              icon: Icons.wb_sunny_outlined,
              label: l.openingTimeLabel,
              time: schedule.openingTime,
              onTap: () => _pickTime(isClosing: false),
              notSetLabel: l.notSet,
            ),
            const SizedBox(height: 8),
            _buildTimeRow(
              icon: Icons.nights_stay_outlined,
              label: l.closingTimeLabel,
              time: schedule.closingTime,
              onTap: () => _pickTime(isClosing: true),
              notSetLabel: l.notSet,
            ),
            if (_saving) ...[
              const SizedBox(height: 8),
              const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
            ] else if (_savedMsg != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(_savedMsg!,
                    style: const TextStyle(fontSize: 11, color: AppColors.success)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required String notSetLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              time != null ? _formatTime(time) : notSetLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: time != null ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
