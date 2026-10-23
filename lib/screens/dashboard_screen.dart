import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/daily_challenge.dart';
import '../models/teammate.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/add_teammate_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip.dart';
import '../widgets/remove_teammate_dialog.dart';
import '../widgets/teammate_card.dart';
import 'team_activity_screen.dart';
import 'teammate_detail_screen.dart';
import 'user_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onRemoveTeammate(Teammate teammate) async {
    final confirmed = await RemoveTeammateDialog.show(context, teammate);
    if (confirmed == true && mounted) {
      final repo = context.read<TeammateRepository>();
      await repo.removeTeammate(teammate.username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurfaceElevated,
            content: Text(
              'Removed @${teammate.username} from roster',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openDailyChallenge(DailyChallenge? challenge) async {
    if (challenge == null || challenge.link.isEmpty) return;
    final uri = Uri.parse(challenge.link);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final teammates = repo.leaderboardTeammates;
    final daily = repo.dailyChallenge;
    final currentUser = repo.currentUserTeammate;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurfaceElevated,
          onRefresh: () => repo.refreshAll(silent: false),
          child: CustomScrollView(
            slivers: [
              // Top Brand Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingM,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // "+ Add Member" Header Action
                      ElevatedButton.icon(
                        onPressed: () => AddTeammateSheet.show(context),
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.textDark,
                        ),
                        label: const Text(
                          'Add Member',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusPill),
                          ),
                        ),
                      ),

                      // Top Right Profile Avatar Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const UserProfileScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.cardSurfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: currentUser?.effectiveAvatar.isNotEmpty ==
                                      true
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      child: Image.network(
                                        currentUser!.effectiveAvatar,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Text(
                                          'H',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'H',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Daily Challenge Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: _buildDailyChallengeCard(daily),
                ),
              ),

              // Live Team Activity Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: _buildTeamActivityBanner(),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => repo.setSearchQuery(val),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search teammates by name or @handle...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                repo.setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Filter & Sort Chips Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.paddingL,
                    right: AppDimensions.paddingL,
                    top: AppDimensions.paddingM,
                    bottom: AppDimensions.paddingM,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'LEADERBOARD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Solved Filter
                        LeetoFilterChip(
                          label: 'Solved',
                          isSelected: repo.sortType == SortType.solved,
                          onTap: () => repo.setSortType(SortType.solved),
                        ),
                        const SizedBox(width: 8),

                        // Streak Filter
                        LeetoFilterChip(
                          label: 'Streak',
                          isSelected: repo.sortType == SortType.streak,
                          onTap: () => repo.setSortType(SortType.streak),
                        ),
                        const SizedBox(width: 8),

                        // Accuracy Filter
                        LeetoFilterChip(
                          label: 'Accuracy',
                          isSelected: repo.sortType == SortType.accuracy,
                          onTap: () => repo.setSortType(SortType.accuracy),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Leaderboard Teammate List
              if (teammates.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: repo.searchQuery.isNotEmpty
                      ? const LeetoEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matching teammates',
                          message: 'Try searching with a different name or handle',
                        )
                      : LeetoEmptyState(
                          icon: Icons.group_off_rounded,
                          title: 'Leaderboard is empty',
                          message: 'Tap "+ Add" above to track your first teammate',
                          action: ElevatedButton.icon(
                            onPressed: () => AddTeammateSheet.show(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Teammate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textDark,
                            ),
                          ),
                        ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingS,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final teammate = teammates[index];
                        return TeammateCard(
                          rank: index + 1,
                          teammate: teammate,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeammateDetailScreen(
                                  username: teammate.username,
                                ),
                              ),
                            );
                          },
                          onRemove: () => _onRemoveTeammate(teammate),
                        );
                      },
                      childCount: teammates.length,
                    ),
                  ),
                ),

              // Bottom safe padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyChallengeCard(DailyChallenge? daily) {
    final title = daily?.title ?? 'Minimum Operations to Sort a Permutation';
    final difficulty = daily?.difficulty ?? 'Medium';
    final topic = daily?.topic ?? 'Array';

    Color diffColor = AppColors.medium;
    if (difficulty.toLowerCase() == 'easy') diffColor = AppColors.easy;
    if (difficulty.toLowerCase() == 'hard') diffColor = AppColors.hard;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.dailyChallengeBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.dailyChallengeBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Challenge Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'DAILY CHALLENGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: diffColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: diffColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Problem Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Topic & Solve Now Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.dailyChallengeTag,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      topic,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Source: LeetCode Official GraphQL',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openDailyChallenge(daily),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '→ Solve Now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamActivityBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TeamActivityScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
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
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.easy,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Team Activity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Today's Team Challenge Active",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
