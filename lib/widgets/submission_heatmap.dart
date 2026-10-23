import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class SubmissionHeatmap extends StatefulWidget {
  final Map<String, int> submissionCalendar;
  final int? totalSubmissions;
  final int? activeDays;
  final int? maxStreak;

  const SubmissionHeatmap({
    super.key,
    required this.submissionCalendar,
    this.totalSubmissions,
    this.activeDays,
    this.maxStreak,
  });

  @override
  State<SubmissionHeatmap> createState() => _SubmissionHeatmapState();
}

class _SubmissionHeatmapState extends State<SubmissionHeatmap> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    // Build map of YYYY-MM-DD -> solve count
    final solveCountsByDate = <String, int>{};
    widget.submissionCalendar.forEach((tsStr, cnt) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts > 0 && cnt > 0) {
        final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
        final ymd =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        solveCountsByDate[ymd] = (solveCountsByDate[ymd] ?? 0) + cnt;
      }
    });

    // 53 weeks (approximately past 12 months)
    // Align so rows are Sun (0) to Sat (6)
    final daysSinceSunday = today.weekday % 7; // Sunday = 0, Mon = 1, ...
    final numWeeks = 53;
    final endDate = today.add(Duration(days: 6 - daysSinceSunday));
    final startDate = endDate.subtract(Duration(days: (numWeeks * 7) - 1));

    // Calculate metrics across past 365 days if not provided
    int calculatedTotal = 0;
    int calculatedActive = 0;
    int calculatedMaxStreak = 0;
    int currentStreak = 0;

    var iterDate = today.subtract(const Duration(days: 364));
    while (!iterDate.isAfter(today)) {
      final ymd =
          '${iterDate.year}-${iterDate.month.toString().padLeft(2, '0')}-${iterDate.day.toString().padLeft(2, '0')}';
      final cnt = solveCountsByDate[ymd] ?? 0;
      calculatedTotal += cnt;
      if (cnt > 0) {
        calculatedActive++;
        currentStreak++;
        if (currentStreak > calculatedMaxStreak) {
          calculatedMaxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
      iterDate = iterDate.add(const Duration(days: 1));
    }

    final displayTotal = widget.totalSubmissions ?? calculatedTotal;
    final displayActive = widget.activeDays ?? calculatedActive;
    final displayMaxStreak = widget.maxStreak ?? calculatedMaxStreak;

    // Group weeks by month for LeetCode-style layout with bottom month labels
    final monthGroups = <_MonthGroup>[];
    _MonthGroup? currentGroup;

    var weekStart = startDate;
    for (int w = 0; w < numWeeks; w++) {
      final weekDays = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        weekDays.add(weekStart.add(Duration(days: d)));
      }

      // Middle day of the week to determine primary month
      final midDay = weekDays[3];
      final monthName = DateFormat('MMM').format(midDay);

      if (currentGroup == null || currentGroup.monthName != monthName) {
        currentGroup = _MonthGroup(monthName: monthName);
        monthGroups.add(currentGroup);
      }
      currentGroup.weeks.add(weekDays);

      weekStart = weekStart.add(const Duration(days: 7));
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Header (LeetCode exact style, wrapped for mobile responsiveness)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Left: Total submissions in past year
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$displayTotal',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'submissions in the past one year',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ],
              ),

              // Right: Total active days & Max streak
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total active days: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '$displayActive',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Max streak: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '$displayMaxStreak',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Horizontal scrollable contribution grid
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: monthGroups.map((group) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Week columns for this month
                      Row(
                        children: group.weeks.map((week) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 3.5),
                            child: Column(
                              children: week.map((date) {
                                final isAfterToday = date.isAfter(today);
                                final isBeforeStart = date.isBefore(today.subtract(const Duration(days: 365)));
                                final ymd =
                                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                final count = solveCountsByDate[ymd] ?? 0;

                                if (isAfterToday || isBeforeStart) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 3.5),
                                    child: SizedBox(width: 10.5, height: 10.5),
                                  );
                                }

                                final cellColor = _getCellColor(count);
                                final dateLabel = DateFormat('MMM d').format(date);
                                final tip = count > 0
                                    ? '$dateLabel: $count submission${count > 1 ? "s" : ""}'
                                    : '$dateLabel: No submissions';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3.5),
                                  child: Tooltip(
                                    message: tip,
                                    waitDuration: const Duration(milliseconds: 300),
                                    child: Container(
                                      width: 10.5,
                                      height: 10.5,
                                      decoration: BoxDecoration(
                                        color: cellColor,
                                        borderRadius:
                                            BorderRadius.circular(2.2),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Month label centered under its group
                      Text(
                        group.monthName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCellColor(int count) {
    if (count == 0) return const Color(0xFF333842); // Subdued dark grey
    if (count <= 2) return const Color(0xFF185324); // Deep green
    if (count <= 5) return const Color(0xFF237530); // Forest green
    if (count <= 8) return const Color(0xFF158E32); // Vibrant green
    return const Color(0xFF7FDF8A); // Light mint green
  }
}

class _MonthGroup {
  final String monthName;
  final List<List<DateTime>> weeks = [];

  _MonthGroup({required this.monthName});
}
