import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/leetcode_profile.dart';
import '../models/teammate.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/stat_card.dart';
import '../widgets/submission_heatmap.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  void _confirmWipeTeammates(BuildContext context, TeammateRepository repo, Teammate currentUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Wipe teammate profiles?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all saved teammate profiles from your local LEETO roster? Your own profile (@${currentUser.username}) will remain intact.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Wipe Teammates',
              style: TextStyle(
                color: AppColors.hard,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final removed = await repo.wipeTeammates();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurfaceElevated,
            content: Text(
              'Removed $removed teammate profile${removed != 1 ? "s" : ""}. Your profile is preserved.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final currentUser = repo.currentUserTeammate;
    final profile = currentUser?.profile;
    final otherCount = repo.otherTeammatesCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: currentUser == null
          ? _buildNoProfileState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  _buildHeader(currentUser),

                  const SizedBox(height: 22),

                  // 2x2 Grid of Key Stats
                  _buildStatsGrid(profile),

                  const SizedBox(height: 20),

                  // Difficulty Breakdown 3 Cards
                  _buildDifficultyBreakdown(profile),

                  const SizedBox(height: 20),

                  // LeetCode-style Contribution Heatmap
                  if (profile != null)
                    SubmissionHeatmap(
                      submissionCalendar: profile.submissionCalendar,
                      totalSubmissions: profile.submissionsInPastOneYear,
                      activeDays: profile.activeDaysInPastOneYear,
                      maxStreak: profile.maxStreakInPastOneYear,
                    ),

                  const SizedBox(height: 20),

                  // "Wipe teammate profiles" Section
                  _buildWipeTeammatesSection(context, repo, currentUser, otherCount),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildNoProfileState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'No Profile Configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your LeetCode handle to the team roster to see your personal analytics.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWipeTeammatesSection(
    BuildContext context,
    TeammateRepository repo,
    Teammate currentUser,
    int otherCount,
  ) {
    final hasTeammates = otherCount > 0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: hasTeammates
              ? AppColors.hard.withValues(alpha: 0.3)
              : AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                size: 18,
                color: hasTeammates ? AppColors.hard : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              const Text(
                'Wipe teammate profiles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Removes all saved teammate profiles from the local LEETO roster. Your own profile (@${currentUser.username}) and stats are preserved.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: hasTeammates
                ? () => _confirmWipeTeammates(context, repo, currentUser)
                : null,
            icon: Icon(
              Icons.delete_outline,
              size: 16,
              color: hasTeammates ? AppColors.hard : AppColors.textMuted,
            ),
            label: Text(
              hasTeammates
                  ? 'Wipe $otherCount Teammate Profile${otherCount != 1 ? "s" : ""}'
                  : 'No teammate profiles to remove',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasTeammates ? AppColors.hard : AppColors.textMuted,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.hard,
              side: BorderSide(
                color: hasTeammates
                    ? AppColors.hard.withValues(alpha: 0.6)
                    : AppColors.cardBorder,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Teammate user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Large Avatar
            if (user.effectiveAvatar.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Image.network(
                  user.effectiveAvatar,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildInitials(user),
                ),
              )
            else
              _buildInitials(user),

            const SizedBox(width: 16),

            // Name & Verified Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.effectiveName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.easy,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Verified LeetCode Member',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInitials(Teammate user) {
    final initial = user.effectiveName.isNotEmpty
        ? user.effectiveName[0].toUpperCase()
        : 'U';
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(LeetCodeProfile? profile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'CONTEST RATING',
                value: profile?.contestRating != null
                    ? '${profile!.contestRating!.toInt()}'
                    : '1452',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'TOTAL SOLVED',
                value: '${profile?.totalSolved ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'ACCURACY',
                value: profile?.accuracy != null
                    ? '${profile!.accuracy!.toStringAsFixed(1)}%'
                    : '75.7%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'CURRENT STREAK',
                value: '${profile?.streak ?? 0} Days',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDifficultyBreakdown(LeetCodeProfile? profile) {
    final easy = profile?.easySolved ?? 0;
    final med = profile?.mediumSolved ?? 0;
    final hard = profile?.hardSolved ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DIFFICULTY BREAKDOWN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDiffBox('Easy', easy, AppColors.easy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDiffBox('Medium', med, AppColors.medium),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDiffBox('Hard', hard, AppColors.hard),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiffBox(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
