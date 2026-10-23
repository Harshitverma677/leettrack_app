import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/leetcode_profile.dart';
import '../models/teammate.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/submission_heatmap.dart';
import '../widgets/submission_tile.dart';

class TeammateDetailScreen extends StatefulWidget {
  final String username;

  const TeammateDetailScreen({
    super.key,
    required this.username,
  });

  @override
  State<TeammateDetailScreen> createState() => _TeammateDetailScreenState();
}

class _TeammateDetailScreenState extends State<TeammateDetailScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final repo = context.read<TeammateRepository>();
      await repo.refreshTeammate(widget.username);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openLeetCodeProfile(String username) async {
    final uri = Uri.parse('https://leetcode.com/$username/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final teammate = repo.findByUsername(widget.username);

    if (teammate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teammate Detail')),
        body: const LeetoEmptyState(
          title: 'Teammate not found',
          message: 'This teammate may have been removed from the roster.',
        ),
      );
    }

    final profile = teammate.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 90,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.chevron_left,
            color: AppColors.primary,
            size: 24,
          ),
          label: const Text(
            'Board',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh profile',
            onPressed: _isRefreshing ? null : _refresh,
          ),
          TextButton.icon(
            onPressed: () => _openLeetCodeProfile(teammate.username),
            icon: const Icon(
              Icons.open_in_new,
              size: 14,
              color: AppColors.primary,
            ),
            label: const Text(
              'Open Profile',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profile == null
          ? const LeetoLoadingState(message: 'Fetching profile data...')
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.cardSurfaceElevated,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header (Avatar, Name, Handle, Streak, Rank)
                    _buildProfileHeader(teammate, profile),

                    const SizedBox(height: 20),

                    // Top 3 Stat Cards: SOLVED, ACCURACY, RATING
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'SOLVED',
                            value: '${profile.totalSolved}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'ACCURACY',
                            value: profile.accuracy != null
                                ? '${profile.accuracy!.toStringAsFixed(1)}%'
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'RATING',
                            value: profile.contestRating != null
                                ? '${profile.contestRating!.toInt()}'
                                : '—',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Difficulty Breakdown Pill/Bar
                    _buildDifficultySection(profile),

                    const SizedBox(height: 16),

                    // Submission Heatmap (1 Year LeetCode Style)
                    SubmissionHeatmap(
                      submissionCalendar: profile.submissionCalendar,
                      totalSubmissions: profile.submissionsInPastOneYear,
                      activeDays: profile.activeDaysInPastOneYear,
                      maxStreak: profile.maxStreakInPastOneYear,
                    ),

                    const SizedBox(height: 16),

                    // DSA Focus Areas
                    if (profile.topTopics.isNotEmpty) ...[
                      _buildDsaFocusAreas(profile.topTopics),
                      const SizedBox(height: 16),
                    ],

                    // Recent Accepted Submissions
                    _buildRecentSubmissions(teammate),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(Teammate teammate, LeetCodeProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Avatar
            _buildAvatar(teammate),
            const SizedBox(width: 14),

            // Name & Handle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teammate.effectiveName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${teammate.username}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Sub-badges: Streak and Rank
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${profile.streak} Day Streak',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (profile.ranking != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rank #${profile.ranking}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(Teammate teammate) {
    final avatar = teammate.effectiveAvatar;
    if (avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(
          avatar,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialsAvatar(teammate),
        ),
      );
    }
    return _buildInitialsAvatar(teammate);
  }

  Widget _buildInitialsAvatar(Teammate teammate) {
    final initial = teammate.effectiveName.isNotEmpty
        ? teammate.effectiveName[0].toUpperCase()
        : 'U';
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySection(LeetCodeProfile profile) {
    final total = profile.totalSolved;
    final easy = profile.easySolved;
    final med = profile.mediumSolved;
    final hard = profile.hardSolved;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
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
          // Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: total > 0
                  ? Row(
                      children: [
                        if (easy > 0)
                          Expanded(
                            flex: ((easy / total) * 1000).toInt(),
                            child: Container(color: AppColors.easy),
                          ),
                        if (med > 0)
                          Expanded(
                            flex: ((med / total) * 1000).toInt(),
                            child: Container(color: AppColors.medium),
                          ),
                        if (hard > 0)
                          Expanded(
                            flex: ((hard / total) * 1000).toInt(),
                            child: Container(color: AppColors.hard),
                          ),
                      ],
                    )
                  : Container(color: AppColors.cardSurfaceElevated),
            ),
          ),

          const SizedBox(height: 12),

          // Counts Row: Easy: 142, Medium: 27, Hard: 0
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDiffCountItem('Easy: $easy', AppColors.easy),
              _buildDiffCountItem('Medium: $med', AppColors.medium),
              _buildDiffCountItem('Hard: $hard', AppColors.hard),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffCountItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDsaFocusAreas(List<TopicCount> topics) {
    final topTopics = topics.take(8).toList();
    final maxSolves = topTopics.isNotEmpty
        ? topTopics
            .map((e) => e.problemsSolved)
            .reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DSA FOCUS AREAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Top Topics',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Topic Progress Rows
          ...topTopics.map((topic) {
            final ratio = maxSolves > 0
                ? (topic.problemsSolved / maxSolves).clamp(0.05, 1.0)
                : 0.1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        topic.tagName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${topic.problemsSolved} solved',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 5,
                      width: double.infinity,
                      color: AppColors.cardSurfaceElevated,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissions(Teammate teammate) {
    final submissions = teammate.recentSubmissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT ACCEPTED SUBMISSIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              '${submissions.length} public solves',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (submissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Center(
              child: Text(
                'No recent public submissions available',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ...submissions.map((sub) => SubmissionTile(submission: sub)),
      ],
    );
  }
}
