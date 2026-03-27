import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

// ── Slidable expense card ─────────────────────────────────────────────────────

/// A swipe-to-reveal card that shows Edit (left) and Delete (right) action slots.
/// Uses a custom [AnimationController] rather than [Dismissible] so that the card
/// snaps back to its original position after the action is triggered, keeping the
/// list stable.
class SlidableExpenseCard extends StatefulWidget {
  final ExpenseModel item;
  final String currency;
  final void Function(VoidCallback closeFn)? onOpened;
  final VoidCallback? onClosed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onCheckTap;

  const SlidableExpenseCard({
    super.key,
    required this.item,
    required this.currency,
    this.onOpened,
    this.onClosed,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.onCheckTap,
  });

  @override
  State<SlidableExpenseCard> createState() => _SlidableExpenseCardState();
}

class _SlidableExpenseCardState extends State<SlidableExpenseCard>
    with SingleTickerProviderStateMixin {
  // The revealed action columns are each _actionW pixels wide.
  static const double _actionW = 80.0;

  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _offset = 0;
  bool _dragging = false;

  // Paid bills cannot be edited, so only the delete action is available.
  bool get _canEdit => !widget.item.isPaid;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _anim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Animate the card to [target] offset (0 = closed, ±_actionW = fully open).
  /// Notifies the page so it can close any other open card before opening this one.
  void _snapTo(double target) {
    final from = _dragging ? _offset : _anim.value;
    _dragging = false;
    _anim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _ctrl..reset(), curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
    if (target != 0) {
      widget.onOpened?.call(_close);
    } else {
      widget.onClosed?.call();
    }
    setState(() {});
  }

  void _close() => _snapTo(0);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final displayOffset = _dragging ? _offset : _anim.value;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _ctrl.stop();
              _offset = _anim.value;
              setState(() => _dragging = true);
            },
            onHorizontalDragUpdate: (d) {
              if (!_dragging) return;
              setState(() {
                _offset += d.delta.dx;
                // Paid bills can only swipe left (delete only).
                _offset = _canEdit
                    ? _offset.clamp(-_actionW, _actionW)
                    : _offset.clamp(-_actionW, 0.0);
              });
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              double target = 0;
              // Snap open if dragged past 50% or flung with enough velocity.
              if (_offset > _actionW * 0.5 || v > 700) {
                target = _canEdit ? _actionW : 0;
              } else if (_offset < -_actionW * 0.5 || v < -700) {
                target = -_actionW;
              }
              _snapTo(target);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      if (_canEdit)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _close();
                              widget.onEdit?.call();
                            },
                            child: Container(
                              color: AppColors.swipeEditBg,
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.only(left: AppSizes.l),
                              child: const ActionLabel(
                                  icon: Icons.edit_outlined, label: 'Edit'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _close();
                            widget.onDelete?.call();
                          },
                          child: Container(
                            color: AppColors.swipeDeleteBg,
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: AppSizes.l),
                            child: const ActionLabel(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(displayOffset, 0),
                  child: ExpenseCard(
                    item: widget.item,
                    currency: widget.currency,
                    onTap: displayOffset == 0 ? widget.onTap : _close,
                    onCheckTap:
                        displayOffset == 0 ? widget.onCheckTap : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Action label ──────────────────────────────────────────────────────────────

/// Icon + text label rendered inside the swipe action background strip.
class ActionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const ActionLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: AppSizes.iconM),
        SizedBox(height: AppSizes.xs),
        Text(label,
            style: TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontXS,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Expense card ──────────────────────────────────────────────────────────────

/// The visible face of a bill row. Renders differently for paid vs. unpaid:
/// - Unpaid: dark gradient with colored category icon.
/// - Paid:   grey-out with green check indicator.
class ExpenseCard extends StatelessWidget {
  final ExpenseModel item;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onCheckTap;

  const ExpenseCard({
    super.key,
    required this.item,
    required this.currency,
    this.onTap,
    this.onCheckTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool paid = item.isPaid;
    final cat = catFor(displayCat(item));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: paid
                  ? [Colors.grey[200]!, Colors.grey[100]!]
                  : [AppColors.primary, AppColors.darkGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: paid
                ? Border.all(
                    color: AppColors.myGreen.withValues(alpha: 0.55),
                    width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: (paid ? AppColors.myGreen : AppColors.primary)
                    .withValues(alpha: paid ? 0.12 : 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m, vertical: AppSizes.m),
            child: Row(
              children: [
                // Category icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: paid
                        ? Colors.grey[300]
                        : cat.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Icon(
                    cat.icon,
                    color: paid ? Colors.grey[500] : cat.color,
                    size: AppSizes.iconM,
                  ),
                ),
                SizedBox(width: AppSizes.m),
                // Name + category label + amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                          color: paid ? Colors.grey[500] : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          color: paid
                              ? Colors.grey[400]
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.amount} $currency',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXXL - 2,
                          fontWeight: FontWeight.w900,
                          color: paid ? Colors.grey[400] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Paid / unpaid check button
                GestureDetector(
                  onTap: onCheckTap,
                  child: Container(
                    padding: EdgeInsets.all(AppSizes.s),
                    decoration: BoxDecoration(
                      color: paid
                          ? AppColors.myGreen.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      paid
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: paid ? AppColors.myGreen : Colors.white60,
                      size: AppSizes.iconM + 4,
                    ),
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
