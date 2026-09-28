import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shop_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/promo_price.dart';
import '../providers/menu_provider.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _percentController;

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;

  /// Il y a une promotion a arreter des qu'un taux ou un prix est pose et que
  /// la fin n'est pas passee.
  ///
  /// Le taux compte autant que le prix : une promotion PROGRAMMEE n'a pas
  /// encore de prix -- il n'est materialise qu'a l'instant du debut -- et le
  /// commercant doit pouvoir l'annuler avant qu'elle ne parte. C'est meme le
  /// seul moment ou l'annuler ne coute rien.
  bool get _hasPromo =>
      (widget.currentDiscountPrice != null || widget.currentPercent != null) &&
      (widget.currentEndTime == null ||
          widget.currentEndTime!.isAfter(DateTime.now()));

  @override
  void initState() {
    super.initState();
    final pct = widget.currentPercent ??
        percentFromPrices(widget.originalPrice, widget.currentDiscountPrice);
    _percentController = TextEditingController(
      text: pct == null ? '' : _trimZeros(pct),
    );
    _startTime = widget.currentStartTime;
    _endTime = widget.currentEndTime;
    _percentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? get _percent => double.tryParse(_percentController.text.replaceAll(',', '.'));

  /// Debut effectif : ce que le commercant a choisi, ou maintenant.
  DateTime get _effectiveStart => _startTime ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(shopSettingsProvider);
    final maxPercent = settingsAsync.valueOrNull?.maxDiscountPercent ?? 70;

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
            _header(maxPercent),
            const SizedBox(height: 20),

            _sectionTitle('Pourcentage de remise'),
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
              validator: (v) => _validatePercent(v, maxPercent),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [10, 20, 30, 50]
                  .where((p) => p <= maxPercent)
                  .map(_quickChip)
                  .toList(),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Début'),
            _dateTile(
              label: _startTime == null
                  ? 'Maintenant, dès l\'enregistrement'
                  : _formatDateTime(_startTime!),
              icon: Icons.play_circle_outline_rounded,
              onTap: () async {
                final picked = await _pickDateTime(
                  initial: _startTime ?? DateTime.now(),
                  firstDate: DateTime.now(),
                );
                if (picked != null) setState(() => _startTime = picked);
              },
              onClear: _startTime == null ? null : () => setState(() => _startTime = null),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Fin'),
            _dateTile(
              label: _endTime == null
                  ? 'Choisir la date de fin'
                  : _formatDateTime(_endTime!),
              icon: Icons.stop_circle_outlined,
              onTap: () async {
                final picked = await _pickDateTime(
                  initial: _endTime ?? _effectiveStart.add(const Duration(days: 7)),
                  firstDate: _effectiveStart,
                );
                if (picked != null) setState(() => _endTime = picked);
              },
              onClear: _endTime == null ? null : () => setState(() => _endTime = null),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _save(maxPercent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _hasPromo
                            ? 'Mettre à jour la promotion'
                            : 'Activer la promotion',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            if (_hasPromo || widget.isCategory) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _stop,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(widget.isCategory
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Validation ───────────────────────────────────────────────────────────

  String? _validatePercent(String? raw, double maxPercent) {
    final v = double.tryParse((raw ?? '').replaceAll(',', '.'));
    if (v == null) return 'Entrez un pourcentage.';
    if (v < 1) return 'Le pourcentage doit être d\'au moins 1 %.';
    if (v > maxPercent) {
      return 'Le maximum autorisé est ${_trimZeros(maxPercent)} %.';
    }
    return null;
  }

  /// Les controles que le formulaire ne peut pas faire seul, parce qu'ils
  /// portent sur la coherence entre deux champs. Chacun a son propre message :
  /// "date invalide" n'apprend rien au commercant.
  String? _validateDates() {
    final now = DateTime.now();
    if (_endTime == null) {
      return 'Choisissez une date de fin.';
    }
    // Une minute de tolerance : le temps de remplir le formulaire, un debut
    // choisi "maintenant" serait sinon deja dans le passe au moment du clic.
    if (_startTime != null &&
        _startTime!.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return 'La date de début ne peut pas être dans le passé.';
    }
    if (!_endTime!.isAfter(_effectiveStart)) {
      return 'La date de fin doit être après la date de début.';
    }
    if (!_endTime!.isAfter(now)) {
      return 'La date de fin est déjà passée.';
    }
    return null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _save(double maxPercent) async {
    if (!_formKey.currentState!.validate()) return;
    final dateError = _validateDates();
    if (dateError != null) {
      _snack(dateError, AppColors.error);
      return;
    }
    final percent = _percent!;

    setState(() => _isLoading = true);
    final repo = ref.read(menuRepositoryProvider);

    if (widget.isCategory) {
      final count = await repo.setPercentPromoForCategory(
        vendorId: widget.vendorId!,
        category: widget.categoryName!,
        percent: percent,
        startTime: _startTime,
        endTime: _endTime,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (count == 0) {
        _snack('Aucun article mis à jour. Réessayez.', AppColors.error);
        return;
      }
      ref.invalidate(menuItemsProvider);
      Navigator.pop(context);
      _snack('$count article(s) en promotion −${_trimZeros(percent)} %.',
          AppColors.success);
      return;
    }

    final ok = await repo.setPercentPromo(
      itemId: widget.itemId!,
      originalPrice: widget.originalPrice,
      percent: percent,
      startTime: _startTime,
      endTime: _endTime,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      _snack('Enregistrement refusé. Vérifiez vos droits et réessayez.',
          AppColors.error);
      return;
    }
    ref.invalidate(menuItemsProvider);
    Navigator.pop(context);
    _snack('Promotion activée : −${_trimZeros(percent)} %.', AppColors.success);
  }

  Future<void> _stop() async {
    setState(() => _isLoading = true);
    final repo = ref.read(menuRepositoryProvider);

    // Ce qui a été posé en une action doit pouvoir être retiré en une action :
    // un commerçant qui a bradé quarante références ne va pas les rouvrir une
    // par une.
    if (widget.isCategory) {
      final count = await repo.clearPromoForCategory(
        vendorId: widget.vendorId!,
        category: widget.categoryName!,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      ref.invalidate(menuItemsProvider);
      Navigator.pop(context);
      _snack(
        count == 0
            ? 'Aucune promotion à arrêter dans cette rubrique.'
            : '$count article(s) revenus à leur prix normal.',
        count == 0 ? AppColors.textLight : AppColors.success,
      );
      return;
    }

    final ok = await repo.clearPromo(widget.itemId!);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      _snack('Impossible d\'arrêter la promotion.', AppColors.error);
      return;
    }
    ref.invalidate(menuItemsProvider);
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

  // ── Presentation ─────────────────────────────────────────────────────────

  /// L'apercu : ancien prix barre, nouveau prix, economie. C'est ce que le
  /// commercant regarde avant de valider, donc il vient du meme calcul que
  /// l'ecriture.
  Widget _header(double maxPercent) {
    final pct = _percent;
    final valid = pct != null && pct >= 1 && pct <= maxPercent;
    final newPrice = valid ? computePromoPrice(widget.originalPrice, pct) : null;

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
            widget.isCategory
                ? '${widget.categoryName} · ${widget.categoryItemCount} article(s)'
                : widget.itemName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (widget.isCategory)
            const Text(
              'Chaque article garde un prix calculé sur le sien : le pourcentage est commun, pas le prix.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.originalPrice.toStringAsFixed(3)} DT',
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
          if (newPrice != null && !widget.isCategory) ...[
            const SizedBox(height: 6),
            Text(
              'Le client économise ${(widget.originalPrice - newPrice).toStringAsFixed(3)} DT.',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );

  Widget _quickChip(int percent) {
    final selected = _percent == percent.toDouble();
    return ChoiceChip(
      label: Text('−$percent %'),
      selected: selected,
      onSelected: (_) {
        _percentController.text = '$percent';
        _percentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _percentController.text.length),
        );
      },
      selectedColor: AppColors.primary.withOpacity(0.18),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
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
