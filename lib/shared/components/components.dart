// ── components.dart ───────────────────────────────────────────────────────────
// Shared UI component library — re-exported and used across all feature pages.
// Contains: ModalHandle, SectionLabel, CardActionButton, cardBgCircle.
// TransactionCard is re-exported from transaction_card.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:financeapp/shared/utils/dates.dart';
import 'package:flutter/material.dart';

export 'transaction_card.dart';

// ── Card balance section ──────────────────────────────────────────────────────

/// Renders the balance area of an account card.
/// Single mode (no debt): shows [label] + big [available] number.
/// Dual mode (loanedAmount > 0): shows a debt badge + AVAILABLE / TOTAL side by side.
class CardBalanceSection extends StatelessWidget {
  final double available;
  final double loanedAmount;
  final String currency;
  /// e.g. 'BALANCE' or 'REMAINING'
  final String label;
  /// Color for large balance numbers.
  final Color mainColor;
  /// Color for labels and currency suffix (usually mainColor with reduced alpha).
  final Color subColor;

  const CardBalanceSection({
    super.key,
    required this.available,
    required this.loanedAmount,
    required this.currency,
    required this.label,
    required this.mainColor,
    required this.subColor,
  });

  bool get _hasDebt => loanedAmount > 0;
  double get _total => available + loanedAmount;

  String _fmt(double v) => fmtNum(v, currency);

  static const _debtAmber = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    if (!_hasDebt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              color: subColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(available),
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.cardBalanceSize,
                  fontWeight: FontWeight.w900,
                  color: mainColor,
                ),
              ),
              SizedBox(width: AppSizes.s),
              Text(
                currency,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Dual mode ─────────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debt badge
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.s, vertical: AppSizes.xs - 1),
          decoration: BoxDecoration(
            color: _debtAmber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border:
                Border.all(color: _debtAmber.withValues(alpha: 0.45), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.handshake_outlined,
                  color: _debtAmber, size: 11),
              const SizedBox(width: 4),
              Text(
                '${_fmt(loanedAmount)} $currency lent',
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _debtAmber,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSizes.xs),

        // Available + divider + Total; shrinks when 4-digit amounts don't fit
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Available (main, large)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AVAILABLE',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: 10,
                      color: subColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _fmt(available),
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.cardBalanceSize,
                          fontWeight: FontWeight.w900,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        currency,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(width: AppSizes.m),
              // Vertical divider
              Container(
                height: 36,
                width: 1,
                margin: EdgeInsets.only(bottom: AppSizes.xs),
                color: subColor.withValues(alpha: 0.25),
              ),
              SizedBox(width: AppSizes.m),

              // Total (secondary, smaller, bottom-aligned)
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: 10,
                        color: subColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _fmt(_total),
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.w700,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          currency,
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: subColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Modal handle bar ──────────────────────────────────────────────────────────

class ModalHandle extends StatelessWidget {
  const ModalHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.handleBarWidth,
        height: AppSizes.handleBarHeight,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

/// Uppercase section header used above grouped content (e.g. 'PERSONAL INFO').
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppSizes.xs),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontSection,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

// ── Card background circle ────────────────────────────────────────────────────

/// Decorative translucent circle used in the card background Stack.
Widget cardBgCircle(double size, double opacity, Color baseColor) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor.withValues(alpha: opacity),
      ),
    );

// ── Card action button ────────────────────────────────────────────────────────

/// Button shown at the bottom of account cards (History, Bills, etc.).
/// Pass [backgroundColor] and [foregroundColor] to match the card theme.
class CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const CardActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: AppSizes.s + 2, horizontal: AppSizes.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: AppSizes.iconS),
                SizedBox(width: AppSizes.xs + 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App Toast ─────────────────────────────────────────────────────────────────

class AppToast {
  static void success(ScaffoldMessengerState messenger, String message) =>
      _show(messenger, message, isSuccess: true);

  static void error(ScaffoldMessengerState messenger, String message) =>
      _show(messenger, message, isSuccess: false);

  static void _show(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isSuccess,
  }) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isSuccess ? AppColors.myGreen : AppColors.myRed)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_rounded
                      : Icons.error_outline_rounded,
                  color: isSuccess ? AppColors.myGreen : AppColors.myRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontS,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            side: BorderSide(
              color: (isSuccess ? AppColors.myGreen : AppColors.myRed)
                  .withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class LightButton extends StatelessWidget {
  final double width;
  final String text;
  final Color textColor;
  final VoidCallback onPressed;

  const LightButton({
    super.key,
    required this.width,
    required this.text,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── Date & Time picker field ──────────────────────────────────────────────────

/// Tappable field that shows the selected [value] as a formatted date/time,
/// or "Now · Auto" when [value] is null (meaning use DateTime.now() at submit).
/// Opens DatePicker → TimePicker on tap; shows an × button to reset to auto.
class DateTimePickerField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const DateTimePickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    onChanged(DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  String _fmt(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month]} ${dt.day}, ${dt.year}  ·  '
        '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.m, vertical: AppSizes.m),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: Colors.grey[400], size: AppSizes.iconM),
            SizedBox(width: AppSizes.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date & Time',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? _fmt(value!) : 'Now  ·  Auto',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontM,
                      color: hasValue ? AppColors.primary : Colors.grey[400],
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close_rounded,
                    color: Colors.grey[400], size: AppSizes.iconS),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tappable date tile (date only) with an X to clear it. While empty it reads
/// "[label] (optional)"; once a date is set, [label] is the small caption above it.
class OptionalDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const OptionalDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 30),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = value;
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.m,
          vertical: AppSizes.m,
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              color: Colors.grey[400],
              size: AppSizes.iconM,
            ),
            SizedBox(width: AppSizes.m),
            Expanded(
              child: date == null
                  ? Text(
                      '$label (optional)',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontM,
                        color: Colors.grey[400],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtDay(date),
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontM,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Tooltip(
                  message: 'Clear date',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.grey[400],
                      size: AppSizes.iconS,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DarkButton extends StatelessWidget {
  final double width;
  final String text;
  final VoidCallback onPressed;

  const DarkButton({
    super.key,
    required this.width,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}
