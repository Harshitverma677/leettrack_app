import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class LeetoFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAddButton;

  const LeetoFilterChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    required this.onTap,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = isAddButton
        ? AppColors.chipBackground
        : (isSelected ? AppColors.chipSelectedBg : AppColors.chipBackground);

    final effectiveBorder = isAddButton
        ? AppColors.primary
        : (isSelected ? AppColors.chipSelectedBorder : AppColors.chipBorder);

    final effectiveColor = isAddButton
        ? AppColors.primary
        : (isSelected ? AppColors.primary : AppColors.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            border: Border.all(
              color: effectiveBorder,
              width: isSelected || isAddButton ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: effectiveColor,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isAddButton
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
