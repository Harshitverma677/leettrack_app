import 'package:flutter/material.dart';
import '../models/teammate.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class TeammateCard extends StatelessWidget {
  final int rank;
  final Teammate teammate;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const TeammateCard({
    super.key,
    required this.rank,
    required this.teammate,
    required this.onTap,
    required this.onRemove,
  });

  bool get isRankOne => rank == 1;

  @override
  Widget build(BuildContext context) {
    final easy = teammate.easySolved;
    final med = teammate.mediumSolved;
    final hard = teammate.hardSolved;
    final total = teammate.totalSolved;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: isRankOne ? AppColors.primary : AppColors.cardBorder,
          width: isRankOne ? 1.5 : AppDimensions.cardBorderWidth,
        ),
        boxShadow: isRankOne
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Rank, Avatar, Name/Handle, Badges, Remove Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rank Badge
                    _buildRankBadge(),
                    const SizedBox(width: 10),

                    // Avatar
                    _buildAvatar(),
                    const SizedBox(width: 12),

                    // Name, Handle & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  teammate.effectiveName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (teammate.isCurrentUser) ...[
                                const SizedBox(width: 6),
                                _buildBadge(
                                  label: 'You',
                                  bgColor: const Color(0xFF1D2845),
                                  textColor: const Color(0xFF60A5FA),
                                  borderColor: const Color(0xFF2E4070),
                                ),
                              ],
                              if (teammate.hasSolvedToday) ...[
                                const SizedBox(width: 6),
                                _buildBadge(
                                  label: 'POTD',
                                  bgColor: const Color(0xFF0C2B22),
                                  textColor: AppColors.easy,
                                  borderColor: const Color(0xFF13533F),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${teammate.username}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Remove Button (✕) - Only shown for peers, never for primary profile
                    if (!teammate.isCurrentUser)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Remove teammate',
                        onPressed: onRemove,
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom Row: Big Solved Number + Difficulty Bar & Breakdown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Solved Count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          total.toString(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'SOLVED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 24),

                    // Difficulty Stacked Bar & Counts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDifficultyBar(easy, med, hard, total),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDifficultyCount(
                                label: 'Easy',
                                count: easy,
                                color: AppColors.easy,
                              ),
                              _buildDifficultyCount(
                                label: 'Med',
                                count: med,
                                color: AppColors.medium,
                              ),
                              _buildDifficultyCount(
                                label: 'Hard',
                                count: hard,
                                color: AppColors.hard,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge() {
    if (isRankOne) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: AppColors.primary,
            width: 1.2,
          ),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events,
                color: AppColors.primary,
                size: 14,
              ),
              Text(
                '1',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatar = teammate.effectiveAvatar;
    if (avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          avatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialsAvatar(),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initial = teammate.effectiveName.isNotEmpty
        ? teammate.effectiveName[0].toUpperCase()
        : 'U';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isRankOne
            ? AppColors.primary.withValues(alpha: 0.15)
            : const Color(0xFF1A263D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRankOne ? AppColors.primary : AppColors.cardBorder,
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isRankOne ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDifficultyBar(int easy, int med, int hard, int total) {
    if (total <= 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    final easyRatio = easy / total;
    final medRatio = med / total;
    final hardRatio = hard / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (easyRatio > 0)
              Expanded(
                flex: (easyRatio * 1000).toInt(),
                child: Container(color: AppColors.easy),
              ),
            if (medRatio > 0)
              Expanded(
                flex: (medRatio * 1000).toInt(),
                child: Container(color: AppColors.medium),
              ),
            if (hardRatio > 0)
              Expanded(
                flex: (hardRatio * 1000).toInt(),
                child: Container(color: AppColors.hard),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCount({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
