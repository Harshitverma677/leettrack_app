import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/daily_challenge.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../utils/url_launcher_helper.dart';
import '../widgets/empty_state.dart';

class TeamActivityScreen extends StatefulWidget {
  const TeamActivityScreen({super.key});

  @override
  State<TeamActivityScreen> createState() => _TeamActivityScreenState();
}

class _TeamActivityScreenState extends State<TeamActivityScreen> {
  int _selectedDayIndex = 0; // 0 = Today, 1 = Yesterday, 2 = 2 days ago, etc.

  Future<void> _openProblem(
    BuildContext context,
    String? titleSlug, {
    String? title,
  }) async {
    await UrlLauncherHelper.openProblemBySlug(
      context,
      titleSlug,
      title: title,
    );
  }

  int _countTeamSolvesOnDate(List<Teammate> teammates, DateTime targetDate) {
    int count = 0;
    for (final t in teammates) {
      for (final sub in t.recentSubmissions) {
        final d = sub.dateTime;
        if (d.year == targetDate.year &&
            d.month == targetDate.month &&
            d.day == targetDate.day) {
          count++;
        }
      }
    }
    return count;
  }

  List<LeetCodeSubmission> _getTeammateSolvesOnDate(
      Teammate teammate, DateTime targetDate) {
    final list = <LeetCodeSubmission>[];
    for (final sub in teammate.recentSubmissions) {
      final d = sub.dateTime;
      if (d.year == targetDate.year &&
          d.month == targetDate.month &&
          d.day == targetDate.day) {
        list.add(sub);
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  String _getDayTitle(int index, DateTime date) {
    if (index == 0) return 'Today';
    if (index == 1) return 'Yesterday';
    return DateFormat('E').format(date); // 'Fri', 'Thu', etc.
  }

  String _formatDateHeading(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today • ${DateFormat('MMM d').format(date)}';
    } else if (date == yesterday) {
      return 'Yesterday • ${DateFormat('MMM d').format(date)}';
    } else {
      if (date.year != now.year) {
        return DateFormat('EEE, MMM d, yyyy').format(date);
      }
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final teammates = repo.leaderboardTeammates;
    final daily = repo.dailyChallenge;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: i)));

    final todaySolves = _countTeamSolvesOnDate(teammates, today);
    final selectedDate = days[_selectedDayIndex];
    final selectedDaySolves = _countTeamSolvesOnDate(teammates, selectedDate);
    final isTodaySelected = _selectedDayIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurfaceElevated,
          onRefresh: () => repo.refreshAll(silent: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Top Custom App Bar matching screenshot
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingM,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // "← Back" button pill
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusM),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusM),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  size: 15,
                                  color: AppColors.textPrimary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // "⚡ 0 Solved (Today)" amber pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D10),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusPill),
                          border: Border.all(
                            color: const Color(0xFF4A3820),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isTodaySelected
                                  ? '$todaySolves Solved (Today)'
                                  : '$selectedDaySolves Solved (${DateFormat('MMM d').format(selectedDate)})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Horizontal Date Selector ("Jump to a Date")
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 94,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                      vertical: AppDimensions.paddingS,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final date = days[index];
                      final isSelected = index == _selectedDayIndex;
                      final daySolves = _countTeamSolvesOnDate(teammates, date);
                      final title = _getDayTitle(index, date);
                      final subLabel = DateFormat('MMM d').format(date);

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDayIndex = index;
                              });
                            },
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusL),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 82,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF161E30)
                                    : AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusL),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.cardBorder,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Day Title ('Today', 'Yesterday', 'Fri')
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // Date Subtitle ('Oct 11')
                                  Text(
                                    subLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  // Bottom count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: daySolves > 0
                                          ? const Color(0xFF0E382B)
                                          : const Color(0xFF0B111F),
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusPill),
                                      border: Border.all(
                                        color: daySolves > 0
                                            ? const Color(0xFF14533F)
                                            : AppColors.cardBorder,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (daySolves > 0) ...[
                                          const Icon(
                                            Icons.bolt,
                                            size: 11,
                                            color: AppColors.easy,
                                          ),
                                          const SizedBox(width: 2),
                                        ],
                                        Text(
                                          '$daySolves',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: daySolves > 0
                                                ? AppColors.easy
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. Date Sub-header Indicator
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.paddingL,
                    right: AppDimensions.paddingL,
                    top: AppDimensions.paddingM,
                    bottom: AppDimensions.paddingS,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateHeading(selectedDate, now),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($selectedDaySolves solve${selectedDaySolves != 1 ? "s" : ""})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Teammate Cards for the Selected Date
              if (teammates.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LeetoEmptyState(
                    icon: Icons.group_off_rounded,
                    title: 'No teammates on leaderboard',
                    message:
                        'Add teammates on the dashboard to track their daily solves.',
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
                        final solvesOnDate =
                            _getTeammateSolvesOnDate(teammate, selectedDate);
                        return _buildTeammateDayCard(
                          context,
                          teammate,
                          solvesOnDate,
                          daily,
                        );
                      },
                      childCount: teammates.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeammateDayCard(
    BuildContext context,
    Teammate teammate,
    List<LeetCodeSubmission> solvesOnDate,
    DailyChallenge? dailyChallenge,
  ) {
    final count = solvesOnDate.length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
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
          // Header Row: Avatar, Name, [You], Handle, [X Solves]
          Row(
            children: [
              _buildAvatar(teammate),
              const SizedBox(width: 12),
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (teammate.isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF261D10),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
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

              // Right pill: "0 Solves" or "X Solves"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: count > 0
                      ? const Color(0xFF0E382B)
                      : const Color(0xFF151E32),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: count > 0
                        ? const Color(0xFF14533F)
                        : const Color(0xFF1D2840),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  '$count Solve${count != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: count > 0 ? AppColors.easy : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content Box: Empty state ("No questions completed on this day.") vs Solved Questions List
          if (count == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B111F),
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                border: Border.all(
                  color: AppColors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
              child: const Center(
                child: Text(
                  'No questions completed on this day.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Column(
              children: solvesOnDate.map((sub) {
                return _buildSolvedQuestionItem(context, sub, dailyChallenge);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSolvedQuestionItem(
    BuildContext context,
    LeetCodeSubmission sub,
    DailyChallenge? dailyChallenge,
  ) {
    Color diffColor = AppColors.textMuted;
    if (sub.difficulty != null) {
      final d = sub.difficulty!.toLowerCase();
      if (d == 'easy') diffColor = AppColors.easy;
      if (d == 'medium') diffColor = AppColors.medium;
      if (d == 'hard') diffColor = AppColors.hard;
    }

    final isPotd = dailyChallenge != null &&
        dailyChallenge.isValid &&
        (sub.titleSlug.trim().toLowerCase() ==
                dailyChallenge.titleSlug.trim().toLowerCase() ||
            sub.title.trim().toLowerCase() ==
                dailyChallenge.title.trim().toLowerCase());

    final timeStr = DateFormat('h:mm a').format(sub.dateTime);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111F),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Solved dot, Problem Title, Time
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.easy,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Bottom Row: Difficulty level pill + POTD badge (if any) + Open action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Difficulty Badge (Easy / Medium / Hard)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sub.difficulty != null
                          ? diffColor.withValues(alpha: 0.15)
                          : AppColors.cardSurfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: sub.difficulty != null
                            ? diffColor.withValues(alpha: 0.4)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      sub.difficulty ?? 'Difficulty unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sub.difficulty != null
                            ? diffColor
                            : AppColors.textMuted,
                      ),
                    ),
                  ),

                  // POTD badge if problem is today's Daily Coding Challenge
                  if (isPotd) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2B22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF13533F),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'POTD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.easy,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Open problem link
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openProblem(
                    context,
                    sub.titleSlug,
                    title: sub.title,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_outward,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
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

  Widget _buildAvatar(Teammate teammate) {
    final avatar = teammate.effectiveAvatar;
    if (avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.network(
          avatar,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitials(teammate),
        ),
      );
    }
    return _buildInitials(teammate);
  }

  Widget _buildInitials(Teammate teammate) {
    final initial = teammate.effectiveName.isNotEmpty
        ? teammate.effectiveName[0].toUpperCase()
        : 'U';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
