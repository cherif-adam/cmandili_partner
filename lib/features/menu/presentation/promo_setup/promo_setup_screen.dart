import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shop_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/promo_price.dart';
import 'promo_setup_controller.dart';

/// Promotion en pourcentage, pour les commerces qui n'utilisent pas le Happy
/// Hour : supermarche, fleuriste, animalerie, cadeaux, electronique.
///
/// La difference de fond avec le Happy Hour n'est pas cosmetique. Le Happy
/// Hour est un PRIX que le restaurateur pose tout de suite ("la pizza a 8 DT
/// ce soir"). La promotion est un POURCENTAGE applique entre deux dates, qu'on
/// peut programmer a l'avance -- une braderie de fleurs le samedi se prepare
/// le mercredi.
///
/// Le prix affiche avant l'enregistrement vient de [computePromoPrice], la
/// meme fonction que celle utilisee pour ecrire en base : le commercant voit
/// le prix exact qui sera encaisse, au millime pres.
///
/// Sur une CATEGORIE d'articles ([categoryName] renseigne), le pourcentage est
/// le meme pour tous mais chaque article garde un prix calcule depuis le sien.
///
/// Top to bottom: _PreviewHeader, the percentage (field + quick chips), the
/// start and end (_DateTile), then the save / stop buttons. UI only: the
/// dates, the rules, saving and stopping live in [PromoSetupController].
class PromoSetupScreen extends ConsumerStatefulWidget {
  /// Article vise, ou null quand la promotion porte sur toute une categorie.
  final String? itemId;
  final String itemName;
  final double originalPrice;

  /// Renseigne pour une promotion de categorie ; [itemId] est alors null.
  final String? categoryName;
  final String? vendorId;
  final int categoryItemCount;

  final double? currentDiscountPrice;
  final double? currentPercent;
  final DateTime? currentStartTime;
  final DateTime? currentEndTime;

  const PromoSetupScreen({
    super.key,
    this.itemId,
    required this.itemName,
    required this.originalPrice,
    this.categoryName,
    this.vendorId,
    this.categoryItemCount = 0,
    this.currentDiscountPrice,
    this.currentPercent,
    this.currentStartTime,
    this.currentEndTime,
  });

  bool get isCategory => categoryName != null;

  @override
  ConsumerState<PromoSetupScreen> createState() => _PromoSetupScreenState();
}

class _PromoSetupScreenState extends ConsumerState<PromoSetupScreen> {
  /// This screen's own controller (see [promoSetupControllerProvider]),
  /// starting from the promotion's current dates.
  late final _provider = promoSetupControllerProvider((
    key: Object(),
    start: widget.currentStartTime,
    end: widget.currentEndTime,
  ));

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _percentController;

  bool get _hasPromo => PromoSetupController.hasPromo(
        currentDiscountPrice: widget.currentDiscountPrice,
        currentPercent: widget.currentPercent,
        currentEndTime: widget.currentEndTime,
      );

  @override
  void initState() {
    super.initState();
    final pct = widget.currentPercent ??
        percentFromPrices(widget.originalPrice, widget.currentDiscountPrice);
    _percentController = TextEditingController(
      text: pct == null ? '' : _trimZeros(pct),
    );
    _percentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? get _percent => PromoSetupController.parsePercent(_percentController.text);

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(shopSettingsProvider);
    final maxPercent = settingsAsync.valueOrNull?.maxDiscountPercent ?? 70;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isCategory ? 'Promotion sur la catégorie' : 'Promotion'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PreviewHeader(
              itemName: widget.itemName,
              originalPrice: widget.originalPrice,
              categoryName: widget.categoryName,
              categoryItemCount: widget.categoryItemCount,
              percent: _percent,
              maxPercent: maxPercent,
            ),
            const SizedBox(height: 20),

            const _SectionTitle('Pourcentage de remise'),
            TextFormField(
              controller: _percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                suffixText: '%',
                hintText: 'Ex : 20',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => _percentErrorText(v, maxPercent),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [10, 20, 30, 50]
                  .where((p) => p <= maxPercent)
                  .map((p) => _QuickChip(
                        percent: p,
                        selected: _percent == p.toDouble(),
                        onSelected: () {
                          _percentController.text = '$p';
                          _percentController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _percentController.text.length),
                          );
                        },
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),
            const _SectionTitle('Début'),
            _DateTile(
              label: state.startTime == null
                  ? 'Maintenant, dès l\'enregistrement'
                  : _formatDateTime(state.startTime!),
              icon: Icons.play_circle_outline_rounded,
              onTap: () async {
                final picked = await _pickDateTime(
                  initial: ref.read(_provider).startTime ?? DateTime.now(),
                  firstDate: DateTime.now(),
                );
                if (picked != null) controller.setStart(picked);
              },
              onClear: state.startTime == null ? null : () => controller.setStart(null),
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Fin'),
            _DateTile(
              label: state.endTime == null
                  ? 'Choisir la date de fin'
                  : _formatDateTime(state.endTime!),
              icon: Icons.stop_circle_outlined,
              onTap: () async {
                final current = ref.read(_provider);
                final picked = await _pickDateTime(
                  initial: current.endTime ?? current.effectiveStart.add(const Duration(days: 7)),
                  firstDate: current.effectiveStart,
                );
                if (picked != null) controller.setEnd(picked);
              },
              onClear: state.endTime == null ? null : () => controller.setEnd(null),
            ),

            const SizedBox(height: 24),
            _SaveButton(
              isLoading: state.isLoading,
              hasPromo: _hasPromo,
              onPressed: () => _save(maxPercent),
            ),

            if (_hasPromo || widget.isCategory) ...[
              const SizedBox(height: 10),
              _StopButton(
                isLoading: state.isLoading,
                isCategory: widget.isCategory,
                onPressed: _stop,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Validation ───────────────────────────────────────────────────────────

  String? _percentErrorText(String? raw, double maxPercent) {
    switch (PromoSetupController.validatePercent(raw, maxPercent)) {
      case PromoPercentError.missing:
        return 'Entrez un pourcentage.';
      case PromoPercentError.belowOne:
        return 'Le pourcentage doit être d\'au moins 1 %.';
      case PromoPercentError.aboveMax:
        return 'Le maximum autorisé est ${_trimZeros(maxPercent)} %.';
      case null:
        return null;
    }
  }

  static String _dateErrorText(PromoDateError error) {
    switch (error) {
      case PromoDateError.missingEnd:
        return 'Choisissez une date de fin.';
      case PromoDateError.startInPast:
        return 'La date de début ne peut pas être dans le passé.';
      case PromoDateError.endBeforeStart:
        return 'La date de fin doit être après la date de début.';
      case PromoDateError.endPassed:
        return 'La date de fin est déjà passée.';
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _save(double maxPercent) async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(_provider.notifier);
    final dateError = controller.validateDates();
    if (dateError != null) {
      _snack(_dateErrorText(dateError), AppColors.error);
      return;
    }
    final percent = _percent!;

    final count = await controller.save(
      percent: percent,
      itemId: widget.itemId,
      originalPrice: widget.originalPrice,
      categoryName: widget.categoryName,
      vendorId: widget.vendorId,
    );
    if (!mounted) return;

    if (widget.isCategory) {
      if (count == 0) {
        _snack('Aucun article mis à jour. Réessayez.', AppColors.error);
        return;
      }
      controller.refreshMenu();
      Navigator.pop(context);
      _snack('$count article(s) en promotion −${_trimZeros(percent)} %.',
          AppColors.success);
      return;
    }

    if (count == 0) {
      _snack('Enregistrement refusé. Vérifiez vos droits et réessayez.',
          AppColors.error);
      return;
    }
    controller.refreshMenu();
    Navigator.pop(context);
    _snack('Promotion activée : −${_trimZeros(percent)} %.', AppColors.success);
  }

  Future<void> _stop() async {
    final controller = ref.read(_provider.notifier);
    final count = await controller.stop(
      itemId: widget.itemId,
      categoryName: widget.categoryName,
      vendorId: widget.vendorId,
    );
    if (!mounted) return;

    if (widget.isCategory) {
      controller.refreshMenu();
      Navigator.pop(context);
      _snack(
        count == 0
            ? 'Aucune promotion à arrêter dans cette rubrique.'
            : '$count article(s) revenus à leur prix normal.',
        count == 0 ? AppColors.textLight : AppColors.success,
      );
      return;
    }

    if (count == 0) {
      _snack('Impossible d\'arrêter la promotion.', AppColors.error);
      return;
    }
    controller.refreshMenu();
    Navigator.pop(context);
    _snack('Promotion arrêtée.', AppColors.success);
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required DateTime firstDate,
  }) async {
    final safeInitial = initial.isBefore(firstDate) ? firstDate : initial;
    final date = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _pickerTheme,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
      builder: _pickerTheme,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      );

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// L'apercu : ancien prix barre, nouveau prix, economie. C'est ce que le
/// commercant regarde avant de valider, donc il vient du meme calcul que
/// l'ecriture.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.itemName,
    required this.originalPrice,
    required this.categoryName,
    required this.categoryItemCount,
    required this.percent,
    required this.maxPercent,
  });

  final String itemName;
  final double originalPrice;
  final String? categoryName;
  final int categoryItemCount;
  final double? percent;
  final double maxPercent;

  bool get isCategory => categoryName != null;

  @override
  Widget build(BuildContext context) {
    final pct = percent;
    final valid = pct != null && pct >= 1 && pct <= maxPercent;
    final newPrice = valid ? computePromoPrice(originalPrice, pct) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCategory
                ? '$categoryName · $categoryItemCount article(s)'
                : itemName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (isCategory)
            const Text(
              'Chaque article garde un prix calculé sur le sien : le pourcentage est commun, pas le prix.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${originalPrice.toStringAsFixed(3)} DT',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                    decoration:
                        newPrice != null ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (newPrice != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${newPrice.toStringAsFixed(3)} DT',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          if (newPrice != null && !isCategory) ...[
            const SizedBox(height: 6),
            Text(
              'Le client économise ${(originalPrice - newPrice).toStringAsFixed(3)} DT.',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.percent,
    required this.selected,
    required this.onSelected,
  });

  final int percent;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('−$percent %'),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withOpacity(0.18),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
                tooltip: 'Effacer',
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isLoading,
    required this.hasPromo,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasPromo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                hasPromo
                    ? 'Mettre à jour la promotion'
                    : 'Activer la promotion',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.isLoading,
    required this.isCategory,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isCategory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: const Icon(Icons.close_rounded),
        label: Text(isCategory
            ? 'Arrêter la promotion de la rubrique'
            : 'Arrêter la promotion'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
