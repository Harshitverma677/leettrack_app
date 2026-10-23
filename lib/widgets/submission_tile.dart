import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/leetcode_submission.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class SubmissionTile extends StatelessWidget {
  final LeetCodeSubmission submission;

  const SubmissionTile({
    super.key,
    required this.submission,
  });

  Future<void> _openProblem(BuildContext context) async {
    final uri = Uri.parse(submission.problemUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open ${submission.problemUrl}')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${submission.problemUrl}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Row(
        children: [
          // Solved Icon
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.easy,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  submission.formattedSolvedDate,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // "Open" Action Button
          OutlinedButton(
            onPressed: () => _openProblem(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              minimumSize: const Size(56, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: const Text(
              'Open',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
