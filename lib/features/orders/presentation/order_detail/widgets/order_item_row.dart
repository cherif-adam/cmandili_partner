import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../widgets/voice_note_player.dart';

/// One ordered item: quantity and name, price, its options, the customer's
/// note and voice note.
class OrderItemRow extends StatelessWidget {
  final dynamic item; // CartItem
  final bool isLast;
  const OrderItemRow({super.key, required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final hasText = (item.specialInstructions as String?)?.isNotEmpty ?? false;
    final hasVoice = (item.voiceNoteContent as String?)?.isNotEmpty ?? false;
    final duration = item.voiceNoteDurationSeconds as int?;
    final optionsSummary = item.optionsSummary as String?;
    final hasOptions = optionsSummary?.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}× ${item.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                '${item.totalPrice.toStringAsFixed(2)} DT',
                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (hasOptions) ...[
            const SizedBox(height: 2),
            Text(
              optionsSummary!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (hasText) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.specialInstructions as String,
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          if (hasVoice) ...[
            const SizedBox(height: 6),
            Builder(builder: (_) {
              final url = item.voiceNoteContent as String;
              // Only render the player for HTTP URLs (uploaded clips). Older
              // orders may still hold a local file path that the partner can't
              // play; show the static badge for those.
              if (url.startsWith('http')) {
                return VoiceNotePlayer(url: url, durationSeconds: duration);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      duration != null ? 'Voice note (${duration}s)' : 'Voice note',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (!isLast) const Divider(height: 16),
        ],
      ),
    );
  }
}
