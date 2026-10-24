import 'package:flutter/material.dart';
import '../models/leetcode_submission.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../utils/url_launcher_helper.dart';

class SubmissionTile extends StatelessWidget {
  final LeetCodeSubmission submission;

  const SubmissionTile({
    super.key,
    required this.submission,
  });

  Future<void> _openProblem(BuildContext context) async {
    await UrlLauncherHelper.openProblemBySlug(
      context,
      submission.titleSlug,
      title: submission.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = submission.hasValidUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          onTap: () => _openProblem(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            child: Row(
              children: [
                // Solved Indicator Dot
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
                    foregroundColor: hasValidUrl
                        ? AppColors.primary
                        : AppColors.textMuted,
                    side: BorderSide(
                      color: hasValidUrl
                          ? AppColors.primary
                          : AppColors.cardBorder,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    minimumSize: const Size(56, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusPill),
                    ),
                  ),
                  child: Text(
                    hasValidUrl ? 'Open' : 'Unavailable',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasValidUrl
                          ? AppColors.primary
                          : AppColors.textMuted,
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
