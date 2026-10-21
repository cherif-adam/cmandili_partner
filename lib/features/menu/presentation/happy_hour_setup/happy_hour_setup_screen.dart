import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'happy_hour_setup_controller.dart';

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
///
/// Top to bottom: _DealHeader, new price (field + quick discounts), start,
/// end (chips + _InfoTile), quantity, the activate / clear buttons, the live
/// note. UI only: the choices, the rules, activating and clearing live in
/// [HappyHourSetupController].
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
  /// This screen's own controller (see [happyHourSetupControllerProvider]),
  /// starting from the deal's current end and quantity.
  late final _provider = happyHourSetupControllerProvider((
    key: Object(),
    currentEndTime: widget.currentEndTime,
    currentQuantity: widget.currentQuantity,
  ));

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;

  bool get _isActive => HappyHourSetupController.isActive(
        currentDiscountPrice: widget.currentDiscountPrice,
        currentEndTime: widget.currentEndTime,
      );

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentDiscountPrice?.toStringAsFixed(2) ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.currentQuantity?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  double? get _price => HappyHourSetupController.parsePrice(_priceController.text);

  int get _percentOff =>
      HappyHourSetupController.percentOff(_price, widget.originalPrice);

  void _applyPercent(int percent) {
    final p = HappyHourSetupController.priceForPercent(widget.originalPrice, percent);
    setState(() => _priceController.text = p.toStringAsFixed(2));
  }

  Future<void> _chooseEnd(HappyHourEnd choice) async {
    final controller = ref.read(_provider.notifier);
    DateTime? custom;
    if (choice == HappyHourEnd.custom) {
      custom = await _pickDateTime();
      if (custom == null) return; // cancelled: keep the previous choice
    }
    if (!mounted) return;
    controller.chooseEnd(choice, customEnd: custom);
  }

  Future<DateTime?> _pickDateTime() async {
    final initial = ref.read(_provider).endTime ?? DateTime.now().add(const Duration(hours: 2));
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
    final controller = ref.read(_provider.notifier);
    if (controller.endIsInPast) {
      _snack(l.hhEndInPast, AppColors.error);
      return;
    }

    final ok = await controller.activate(
      itemId: widget.itemId,
      price: _price!,
      quantityText: _quantityController.text,
    );
    if (!mounted) return;
    if (ok) {
      controller.refreshMenu();
      Navigator.pop(context);
      _snack(l.happyHourActivated, AppColors.success);
    } else {
      _snack(l.happyHourFailed, AppColors.error);
    }
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context)!;
    final controller = ref.read(_provider.notifier);
    final ok = await controller.clear(widget.itemId);
    if (!mounted) return;
    if (ok) {
      controller.refreshMenu();
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

  void _step(int delta) {
    final current = int.tryParse(_quantityController.text) ?? 0;
    final next = (current + delta).clamp(1, 9999);
    setState(() => _quantityController.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
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
              _DealHeader(
                itemName: widget.itemName,
                price: _price,
                percent: percent,
                original: original,
                limited: state.limited,
                quantityText: _quantityController.text,
              ),
              const SizedBox(height: 24),

              // ── New price ───────────────────────────────────────────────
              _SectionTitle(l.hhNewPrice),
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
                  switch (HappyHourSetupController.validatePrice(v, widget.originalPrice)) {
                    case HappyHourFieldError.priceRequired:
                      return l.hhPriceRequired;
                    case HappyHourFieldError.priceInvalid:
                      return l.hhPriceInvalid;
                    case HappyHourFieldError.priceTooHigh:
                      return l.hhPriceTooHigh(original);
                    case HappyHourFieldError.quantityInvalid:
                    case null:
                      return null;
                  }
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
              _SectionTitle(l.hhStart),
              _InfoTile(
                icon: Icons.play_circle_fill_rounded,
                title: _isActive ? l.hhActiveNow : l.hhStartsNow,
                highlighted: true,
              ),

              const SizedBox(height: 24),

              // ── End (optional) ─────────────────────────────────────────
              _SectionTitle(l.hhEnd),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, choice) in [
                    (l.hhNoEnd, HappyHourEnd.none),
                    ('+1 h', HappyHourEnd.plus1h),
                    ('+2 h', HappyHourEnd.plus2h),
                    ('+3 h', HappyHourEnd.plus3h),
                    (l.hhEndOfDay, HappyHourEnd.tonight),
                    (l.hhOtherDate, HappyHourEnd.custom),
                  ])
                    _EndChip(
                      label: label,
                      selected: state.endChoice == choice,
                      onSelected: () => _chooseEnd(choice),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: state.endTime == null
                    ? Icons.all_inclusive_rounded
                    : Icons.timer_outlined,
                title: state.endTime == null
                    ? l.hhNoEndHint
                    : l.hhEndsAt(_formatDateTime(state.endTime!)),
                highlighted: state.endTime != null,
              ),

              const SizedBox(height: 24),

              // ── Quantity (optional) ────────────────────────────────────
              _SectionTitle(l.hhQuantity),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.hhUnlimited),
                    selected: !state.limited,
                    onSelected: (_) => controller.setLimited(false),
                    selectedColor: AppColors.secondary.withOpacity(0.18),
                  ),
                  ChoiceChip(
                    label: Text(l.hhLimited),
                    selected: state.limited,
                    onSelected: (_) => controller.setLimited(true),
                    selectedColor: AppColors.secondary.withOpacity(0.18),
                  ),
                ],
              ),
              if (state.limited) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StepButton(icon: Icons.remove_rounded, onTap: () => _step(-1)),
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
                        validator: (v) => controller.validateQuantity(v) != null
                            ? l.hhQuantityInvalid
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StepButton(icon: Icons.add_rounded, onTap: () => _step(1)),
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
                  onPressed: state.isLoading ? null : _activate,
                  icon: state.isLoading
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
                    onPressed: state.isLoading ? null : _clear,
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
              const _LiveNote(),
            ],
          ),
        ),
      ),
    );
  }

  /// "26/09 21:30" — short enough for one line in any of the three languages.
  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
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

// ── Sections ──────────────────────────────────────────────────────────────────

/// Item name, the normal price, and a live preview of the deal: new price
/// and discount badge update as the partner types.
class _DealHeader extends StatelessWidget {
  const _DealHeader({
    required this.itemName,
    required this.price,
    required this.percent,
    required this.original,
    required this.limited,
    required this.quantityText,
  });

  final String itemName;
  final double? price;
  final int percent;
  final String original;
  final bool limited;
  final String quantityText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = this.price;
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
                  itemName,
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
                if (limited &&
                    (int.tryParse(quantityText) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.hhUnitsLeft(int.parse(quantityText)),
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

class _EndChip extends StatelessWidget {
  const _EndChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.secondary.withOpacity(0.18),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.secondary : AppColors.textPrimary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
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
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 52,
          child: Icon(icon, color: AppColors.secondary),
        ),
      ),
    );
  }
}

class _LiveNote extends StatelessWidget {
  const _LiveNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
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
    );
  }
}
