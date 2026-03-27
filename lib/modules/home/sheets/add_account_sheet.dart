import 'package:financeapp/modules/home/cards/customAccountCard.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet for creating a new custom account.
/// Lets the user pick a name, gradient color, and icon before submitting.
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _nameCtrl = TextEditingController();
  int _selectedColor = 0;
  int _selectedIcon = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXXL)),
        ),
        padding: EdgeInsets.fromLTRB(
            AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModalHandle(),
            SizedBox(height: AppSizes.l),
            Text(
              AppStrings.newAccount,
              style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
            SizedBox(height: AppSizes.l),

            // Name field
            Container(
              decoration: BoxDecoration(
                color: AppColors.pageBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
              ),
              child: TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontM,
                    color: AppColors.primary),
                decoration: InputDecoration(
                  hintText: AppStrings.accountName,
                  hintStyle:
                      TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.m, vertical: AppSizes.m),
                ),
              ),
            ),
            SizedBox(height: AppSizes.l),

            // Color picker
            Text(AppStrings.color,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            SizedBox(height: AppSizes.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(kCustomAccountColors.length, (i) {
                final selected = i == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          kCustomAccountColors[i][0],
                          kCustomAccountColors[i][1]
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: selected
                          ? Border.all(color: AppColors.primary, width: 2.5)
                          : null,
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }),
            ),
            SizedBox(height: AppSizes.l),

            // Icon picker
            Text(AppStrings.icon,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            SizedBox(height: AppSizes.s),
            Wrap(
              spacing: AppSizes.s,
              runSpacing: AppSizes.s,
              children: List.generate(kCustomAccountIcons.length, (i) {
                final selected = i == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = i),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? kCustomAccountColors[_selectedColor][0]
                              .withValues(alpha: 0.15)
                          : AppColors.pageBackground,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: selected
                          ? Border.all(
                              color: kCustomAccountColors[_selectedColor][0],
                              width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      kCustomAccountIcons[i],
                      size: 20,
                      color: selected
                          ? kCustomAccountColors[_selectedColor][0]
                          : Colors.grey[500],
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: AppSizes.l),

            // Create button
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusL)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        AppStrings.createAccount,
                        style: TextStyle(
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontM,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final icon = kCustomAccountIcons[_selectedIcon];
    await ref.read(accountsProvider.notifier).addCustomAccount(
          name,
          _selectedColor,
          icon.codePoint,
        );
    if (mounted) Navigator.pop(context, true);
  }
}
