import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/menu_provider.dart';

/// How the partner chose the end of the deal. Kept separately from the
/// resulting DateTime so the matching chip stays highlighted.
enum _EndChoice { none, plus1h, plus2h, plus3h, tonight, custom }

/// Sets up a happy hour on one item: the reduced price, when it ends (or
/// never), and how many units are sold at that price (or unlimited).
///
/// The deal always starts now, on activation. The end and the quantity are
/// both optional — "pizzas at 8 DT until I stop it" and "7 pizzas at 8 DT
/// until 22:00" are both valid set-ups. A limited quantity is counted down by
/// the database on every order line and the deal ends itself at zero.
///
/// Works for every shop category: the write goes to vendor_items directly
/// (see MenuRepository.setHappyHour).
class HappyHourSetupScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final double originalPrice;
  final double? currentDiscountPrice;
  final DateTime? currentEndTime;
  final int? currentQuantity;

  const HappyHourSetupScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.originalPrice,
    this.currentDiscountPrice,
    this.currentEndTime,
    this.currentQuantity,
  });

  @override
  ConsumerState<HappyHourSetupScreen> createState() =>
      _HappyHourSetupScreenState();
}

class _HappyHourSetupScreenState extends ConsumerState<HappyHourSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;

  _EndChoice _endChoice = _EndChoice.none;
  DateTime? _endTime;
  bool _limited = false;
  bool _isLoading = false;

  /// A deal counts as running when it has a price and has not passed its
  /// end. A deal with no end date is running until it is cleared.
  bool get _isActive =>
      widget.currentDiscountPrice != null &&
      (widget.currentEndTime == null ||
          widget.currentEndTime!.isAfter(DateTime.now()));

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentDiscountPrice?.toStringAsFixed(2) ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.currentQuantity?.toString() ?? '',
    );
    _limited = widget.currentQuantity != null;
    final end = widget.currentEndTime;
    if (end != null && end.isAfter(DateTime.now())) {
      _endTime = end;
      _endChoice = _EndChoice.custom;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  double? get _price =>
      double.tryParse(_priceController.text.replaceAll(',', '.'));

  int get _percentOff {
    final p = _price;
    if (p == null || p <= 0 || p >= widget.originalPrice) return 0;
    return ((widget.originalPrice - p) / widget.originalPrice * 100).round();
  }

  void _applyPercent(int percent) {
    final p = widget.originalPrice * (100 - percent) / 100;
    setState(() => _priceController.text = p.toStringAsFixed(2));
  }

  Future<void> _chooseEnd(_EndChoice choice) async {
    final now = DateTime.now();
    DateTime? end;
    switch (choice) {
      case _EndChoice.none:
        end = null;
      case _EndChoice.plus1h:
        end = now.add(const Duration(hours: 1));
      case _EndChoice.plus2h:
        end = now.add(const Duration(hours: 2));
      case _EndChoice.plus3h:
        end = now.add(const Duration(hours: 3));
      case _EndChoice.tonight:
        end = DateTime(now.year, now.month, now.day, 23, 59);
      case _EndChoice.custom:
        end = await _pickDateTime();
        if (end == null) return; // cancelled: keep the previous choice
    }
    if (!mounted) return;
    setState(() {
      _endChoice = choice;
      _endTime = end;
    });
  }

  Future<DateTime?> _pickDateTime() async {
    final initial = _endTime ?? DateTime.now().add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: _pickerTheme,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: _pickerTheme,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      );

  Future<void> _activate() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_endTime != null && !_endTime!.isAfter(DateTime.now())) {
      _snack(l.hhEndInPast, AppColors.error);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(menuRepositoryProvider).setHappyHour(
          itemId: widget.itemId,
          discountPrice: _price!,
          endTime: _endTime,
          quantity: _limited ? int.parse(_quantityController.text) : null,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ref.invalidate(menuItemsProvider);
      Navigator.pop(context);
      _snack(l.happyHourActivated, AppColors.success);
    } else {
      _snack(l.happyHourFailed, AppColors.error);
    }
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    final ok =
        await ref.read(menuRepositoryProvider).clearHappyHour(widget.itemId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ref.invalidate(menuItemsProvider);
      Navigator.pop(context);
      _snack(l.happyHourCleared, null);
    } else {
      _snack(l.happyHourFailed, AppColors.error);
    }
  }

  void _snack(String text, Color? color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final percent = _percentOff;
    final original = widget.originalPrice.toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.happyHourSetup),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(l, percent, original),
              const SizedBox(height: 24),

              // ── New price ───────────────────────────────────────────────
              _sectionTitle(l.hhNewPrice),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration(
                  hint: (widget.originalPrice * 0.8).toStringAsFixed(2),
                  icon: Icons.price_change_rounded,
                  suffix: 'DT',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.hhPriceRequired;
                  final d = _price;
                  if (d == null || d <= 0) return l.hhPriceInvalid;
                  if (d >= widget.originalPrice) {
                    return l.hhPriceTooHigh(original);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Text(l.hhQuickDiscount,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in const [10, 20, 30, 50])
                    ChoiceChip(
                      label: Text('-$p%'),
                      selected: percent == p,
                      onSelected: (_) => _applyPercent(p),
                      selectedColor: AppColors.secondary.withOpacity(0.18),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: percent == p
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Start ──────────────────────────────────────────────────
              _sectionTitle(l.hhStart),
              _infoTile(
                icon: Icons.play_circle_fill_rounded,
                title: _isActive ? l.hhActiveNow : l.hhStartsNow,
                highlighted: true,
              ),

              const SizedBox(height: 24),

              // ── End (optional) ─────────────────────────────────────────
              _sectionTitle(l.hhEnd),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _endChip(l.hhNoEnd, _EndChoice.none),
                  _endChip('+1 h', _EndChoice.plus1h),
                  _endChip('+2 h', _EndChoice.plus2h),
                  _endChip('+3 h', _EndChoice.plus3h),
                  _endChip(l.hhEndOfDay, _EndChoice.tonight),
                  _endChip(l.hhOtherDate, _EndChoice.custom),
                ],
              ),
              const SizedBox(height: 10),
              _infoTile(
                icon: _endTime == null
                    ? Icons.all_inclusive_rounded
                    : Icons.timer_outlined,
                title: _endTime == null
                    ? l.hhNoEndHint
                    : l.hhEndsAt(_formatDateTime(_endTime!)),
                highlighted: _endTime != null,
              ),

              const SizedBox(height: 24),

              // ── Quantity (optional) ────────────────────────────────────
              _sectionTitle(l.hhQuantity),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.hhUnlimited),
                    selected: !_limited,
                    onSelected: (_) => setState(() => _limited = false),
                    selectedColor: AppColors.secondary.withOpacity(0.18),
                  ),
                  ChoiceChip(
                    label: Text(l.hhLimited),
                    selected: _limited,
                    onSelected: (_) => setState(() => _limited = true),
                    selectedColor: AppColors.secondary.withOpacity(0.18),
                  ),
                ],
              ),
              if (_limited) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stepButton(Icons.remove_rounded, -1),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _inputDecoration(
                          hint: l.hhQuantityHint,
                          icon: Icons.inventory_2_rounded,
                        ),
                        validator: (v) {
                          if (!_limited) return null;
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1) return l.hhQuantityInvalid;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _stepButton(Icons.add_rounded, 1),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.hhQuantityHelp,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _activate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.local_fire_department_rounded),
                  label: Text(
                    _isActive ? l.hhUpdate : l.activateHappyHour,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: AppColors.secondary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              if (_isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _clear,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l.clearHappyHour,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side:
                          const BorderSide(color: AppColors.error, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.hhLiveInfo,
                        style: const TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Item name, the normal price, and a live preview of the deal: new price
  /// and discount badge update as the partner types.
  Widget _header(AppLocalizations l, int percent, String original) {
    final price = _price;
    final hasDeal = percent > 0 && price != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                if (hasDeal)
                  Row(
                    children: [
                      Text(
                        '${price.toStringAsFixed(2)} DT',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$original DT',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    l.hhNormalPrice(original),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                if (_limited &&
                    (int.tryParse(_quantityController.text) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.hhUnitsLeft(int.parse(_quantityController.text)),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (hasDeal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '-$percent%',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
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

  Widget _endChip(String label, _EndChoice choice) {
    final selected = _endChoice == choice;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _chooseEnd(choice),
      selectedColor: AppColors.secondary.withOpacity(0.18),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.secondary : AppColors.textPrimary,
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? AppColors.secondary.withOpacity(0.6)
              : AppColors.textLight.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: highlighted ? AppColors.secondary : AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                color: highlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, int delta) {
    return Material(
      color: AppColors.secondary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final current = int.tryParse(_quantityController.text) ?? 0;
          final next = (current + delta).clamp(1, 9999);
          setState(() => _quantityController.text = '$next');
        },
        child: SizedBox(
          width: 48,
          height: 52,
          child: Icon(icon, color: AppColors.secondary),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixText: suffix,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppColors.textLight.withOpacity(0.15), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  /// "26/09 21:30" — short enough for one line in any of the three languages.
  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
