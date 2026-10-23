import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class SubmissionHeatmap extends StatefulWidget {
  final Map<String, int> submissionCalendar;
  final int? totalSubmissions;
  final int? activeDays;
  final int? maxStreak;
  final bool isLoading;
  final bool isUnavailable;
  final VoidCallback? onRetry;

  const SubmissionHeatmap({
    super.key,
    required this.submissionCalendar,
    this.totalSubmissions,
    this.activeDays,
    this.maxStreak,
    this.isLoading = false,
    this.isUnavailable = false,
    this.onRetry,
  });

  @override
  State<SubmissionHeatmap> createState() => _SubmissionHeatmapState();
}

class _SubmissionHeatmapState extends State<SubmissionHeatmap> {
  late final ScrollController _scrollController;

  static const double _cellSize = 11.0;
  static const double _cellSpacing = 3.0;
  static const double _monthSpacing = 14.0; // Noticeably larger gap between months

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
    if (widget.isLoading) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2228),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (widget.isUnavailable) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2228),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 28, color: AppColors.textMuted),
            const SizedBox(height: 8),
            const Text(
              'Submission calendar data unavailable',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Could not verify calendar from LeetCode public GraphQL response.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    // Build map of YYYY-MM-DD -> solve count from verified calendar data
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

    // Build past 12 months data
    final months = <_MonthData>[];
    for (int i = 11; i >= 0; i--) {
      int m = today.month - i;
      int y = today.year;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      months.add(_buildMonthData(y, m, today, solveCountsByDate));
    }

    // Calculate real stats across the displayed 12-month period
    final firstDisplayedDate =
        DateTime.utc(months.first.year, months.first.month, 1);
    int calculatedTotal = 0;
    int calculatedActive = 0;
    int calculatedMaxStreak = 0;
    int currentStreak = 0;

    var iterDate = firstDisplayedDate;
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

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2228),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.cardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LeetCode Summary Header
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

          // Horizontal scrollable real calendar grid with separated months
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: months.asMap().entries.map((entry) {
                final idx = entry.key;
                final month = entry.value;
                final isLast = idx == months.length - 1;
                return Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : _monthSpacing),
                  child: _buildMonthGroup(month),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  _MonthData _buildMonthData(
    int year,
    int month,
    DateTime today,
    Map<String, int> solveCountsByDate,
  ) {
    final firstDay = DateTime.utc(year, month, 1);
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    final isCurrentMonth = (year == today.year && month == today.month);
    final lastDay = isCurrentMonth ? today.day : daysInMonth;

    // Sunday-first weekday index: Sun = 0, Mon = 1, ..., Sat = 6
    final startWeekday = firstDay.weekday % 7;
    final numCols = ((startWeekday + lastDay + 6) ~/ 7);

    final columns = <List<_CellData>>[];

    for (int c = 0; c < numCols; c++) {
      final colCells = <_CellData>[];
      for (int r = 0; r < 7; r++) {
        final dayNum = (c * 7) + r - startWeekday + 1;
        if (dayNum >= 1 && dayNum <= lastDay) {
          final date = DateTime.utc(year, month, dayNum);
          final ymd =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final count = solveCountsByDate[ymd] ?? 0;
          colCells.add(_CellData(
            date: date,
            solveCount: count,
            isPlaceholder: false,
          ));
        } else {
          // Layout placeholder for weekdays outside this month or after today
          colCells.add(const _CellData.placeholder());
        }
      }
      columns.add(colCells);
    }

    final monthLabel = DateFormat('MMM').format(firstDay);

    return _MonthData(
      year: year,
      month: month,
      label: monthLabel,
      columns: columns,
    );
  }

  Widget _buildMonthGroup(_MonthData month) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Month's week columns
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: month.columns.map((col) {
            return Padding(
              padding: const EdgeInsets.only(right: _cellSpacing),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: col.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _cellSpacing),
                    child: cell.isPlaceholder
                        ? const SizedBox(
                            width: _cellSize,
                            height: _cellSize,
                          )
                        : _buildCell(cell),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        // Month Label centered under this month's columns
        Text(
          month.label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCell(_CellData cell) {
    final count = cell.solveCount;
    final date = cell.date!;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(date);
    final tip = count > 0
        ? '$dateLabel: $count solve${count > 1 ? "s" : ""}'
        : '$dateLabel: No submissions';

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 250),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          color: _getCellColor(count),
          borderRadius: BorderRadius.circular(2.2),
        ),
      ),
    );
  }

  Color _getCellColor(int count) {
    if (count == 0) return const Color(0xFF2D3139); // Subdued charcoal inactive cell
    if (count <= 2) return const Color(0xFF185324); // Level 1 muted green
    if (count <= 5) return const Color(0xFF237530); // Level 2 forest green
    if (count <= 8) return const Color(0xFF158E32); // Level 3 emerald green
    return const Color(0xFF7FDF8A); // Level 4 light mint green
  }
}

class _CellData {
  final DateTime? date;
  final int solveCount;
  final bool isPlaceholder;

  const _CellData({
    required this.date,
    required this.solveCount,
    required this.isPlaceholder,
  });

  const _CellData.placeholder()
      : date = null,
        solveCount = 0,
        isPlaceholder = true;
}

class _MonthData {
  final int year;
  final int month;
  final String label;
  final List<List<_CellData>> columns;

  const _MonthData({
    required this.year,
    required this.month,
    required this.label,
    required this.columns,
  });
}
