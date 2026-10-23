import 'package:flutter/material.dart';
import '../models/teammate.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class RemoveTeammateDialog extends StatelessWidget {
  final Teammate teammate;
  final VoidCallback onConfirm;

  const RemoveTeammateDialog({
    super.key,
    required this.teammate,
    required this.onConfirm,
  });

  static Future<bool?> show(BuildContext context, Teammate teammate) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => RemoveTeammateDialog(
        teammate: teammate,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        side: const BorderSide(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      title: const Text(
        'Remove Teammate',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Are you sure you want to remove ${teammate.effectiveName} (@${teammate.username}) from the team?',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text(
            'Remove',
            style: TextStyle(
              color: AppColors.hard,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
