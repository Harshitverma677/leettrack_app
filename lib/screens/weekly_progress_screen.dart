import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/stat_card.dart';

class WeeklyProgressScreen extends StatelessWidget {
  const WeeklyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final currentUser = repo.currentUserTeammate;
    final dailyGoal = repo.dailyGoal;
    final profile = currentUser?.profile;

    // Calculate last 7 days data from real submission calendar
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);

    final days = <_DailySolveStat>[];
    int totalWeekSolves = 0;
    int activeDays = 0;

    for (int i = 6; i >= 0; i--) {
      final date = todayUtc.subtract(Duration(days: i));
      final solves = profile?.getSolvesOnDate(date) ?? 0;
      totalWeekSolves += solves;
      if (solves > 0) activeDays++;

      days.add(_DailySolveStat(
        date: date,
        dayName: DateFormat('E').format(date),
        dayNumber: date.day,
        solves: solves,
        isToday: i == 0,
        metGoal: solves >= dailyGoal,
      ));
    }

    final dailyAverage = (totalWeekSolves / 7.0).toStringAsFixed(1);
    final isGoalMetOverall = activeDays >= 5 && totalWeekSolves >= (dailyGoal * 7);

    final maxSolvesInWeek = days.isNotEmpty
        ? days.map((e) => e.solves).reduce((a, b) => a > b ? a : b)
        : 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Progress'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User context pill
            if (currentUser != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tracking: ${currentUser.effectiveName} (@${currentUser.username})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            // Top Stat Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'ACTIVE DAYS',
                    value: '$activeDays / 7',
                    subtitle: 'Past 7 days',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: 'DAILY AVG',
                    value: dailyAverage,
                    subtitle: 'Solves / day',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: 'GOAL STATUS',
                    value: isGoalMetOverall ? 'Met' : 'Pending',
                    accentColor:
                        isGoalMetOverall ? AppColors.easy : AppColors.medium,
                    subtitle: '$dailyGoal / day goal',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Solves by Day Bar Chart Card
            Container(
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
                        'SOLVES BY DAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '$totalWeekSolves total this week',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bar Chart
                  SizedBox(
                    height: 160,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.map((day) {
                        final ratio = maxSolvesInWeek > 0
                            ? (day.solves / maxSolvesInWeek).clamp(0.06, 1.0)
                            : 0.06;

                        final barColor = day.solves > 0
                            ? (day.metGoal
                                ? AppColors.easy
                                : AppColors.primary)
                            : AppColors.cardSurfaceElevated;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Solve count above bar
                            Text(
                              day.solves > 0 ? '${day.solves}' : '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: day.isToday
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // The Bar
                            Container(
                              width: 28,
                              height: 100 * ratio,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(6),
                                border: day.isToday
                                    ? Border.all(
                                        color: AppColors.primaryLight,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Day Label
                            Text(
                              day.dayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: day.isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: day.isToday
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Daily Activity Breakdown List
            Container(
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
                  const Text(
                    'DAILY BREAKDOWN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...days.reversed.map((day) {
                    final dateFormatted =
                        DateFormat('EEEE, MMM d').format(day.date);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: day.solves > 0
                                      ? AppColors.easy
                                      : AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dateFormatted,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: day.isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: day.isToday
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (day.isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTransparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Today',
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
                          Text(
                            '${day.solves} solved',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: day.solves > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySolveStat {
  final DateTime date;
  final String dayName;
  final int dayNumber;
  final int solves;
  final bool isToday;
  final bool metGoal;

  _DailySolveStat({
    required this.date,
    required this.dayName,
    required this.dayNumber,
    required this.solves,
    required this.isToday,
    required this.metGoal,
  });
}
