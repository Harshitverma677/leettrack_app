import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../utils/url_launcher_helper.dart';
import '../widgets/empty_state.dart';

class TeamActivityScreen extends StatelessWidget {
  const TeamActivityScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final teammates = repo.rawTeammates;

    // Filter by timestamp: strictly rolling past 7 days (7 * 86400 seconds)
    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final sevenDaysAgoSeconds = nowSeconds - (7 * 86400);

    final qualifyingItems = <_ActivityItem>[];
    for (final teammate in teammates) {
      for (final sub in teammate.recentSubmissions) {
        if (sub.timestamp >= sevenDaysAgoSeconds) {
          qualifyingItems.add(_ActivityItem(
            teammate: teammate,
            submission: sub,
          ));
        }
      }
    }

    // Group submissions by date string (YYYY-MM-DD in local time)
    final groupedByDate = <String, List<_ActivityItem>>{};
    for (final item in qualifyingItems) {
      final dt = item.submission.dateTime;
      final dateKey =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      groupedByDate.putIfAbsent(dateKey, () => []).add(item);
    }

    // Sort date keys descending (newest day first)
    final sortedDateKeys = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Sort submissions within each day newest first
    for (final dateKey in sortedDateKeys) {
      groupedByDate[dateKey]!.sort(
          (a, b) => b.submission.timestamp.compareTo(a.submission.timestamp));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Team Activity'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: AppColors.primary, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Text(
                  '${qualifyingItems.length} solves (7d)',
                  style: const TextStyle(
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
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardSurfaceElevated,
        onRefresh: () => repo.refreshAll(silent: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.easy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'solves from past 7 days',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Activity Feed: grouped by date with separate date headings
              if (qualifyingItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LeetoEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No submissions in the past 7 days',
                    message:
                        'Zero Submission',
                  ),
                )
              else
                ...sortedDateKeys.map((dateKey) {
                  final itemsOnDate = groupedByDate[dateKey]!;
                  final dateHeading = _formatDateHeading(dateKey, now);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Heading (e.g. "Today • Oct 23" or "Yesterday" or "Oct 21")
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 8, bottom: 10, left: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateHeading,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${itemsOnDate.length} solve${itemsOnDate.length > 1 ? "s" : ""})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Every submission rendered as its own distinct card/row
                      ...itemsOnDate.map((item) {
                        return _buildActivityCard(context, item);
                      }),

                      const SizedBox(height: 10),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateHeading(String dateKey, DateTime now) {
    try {
      final parts = dateKey.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final dt = DateTime(y, m, d);

      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (dt == today) {
        return 'Today • ${DateFormat('MMM d').format(dt)}';
      } else if (dt == yesterday) {
        return 'Yesterday • ${DateFormat('MMM d').format(dt)}';
      } else {
        if (dt.year != now.year) {
          return DateFormat('EEE, MMM d, yyyy').format(dt);
        }
        return DateFormat('EEEE, MMM d').format(dt);
      }
    } catch (_) {
      return dateKey;
    }
  }

  Widget _buildActivityCard(BuildContext context, _ActivityItem item) {
    final sub = item.submission;
    final teammate = item.teammate;

    Color diffColor = AppColors.textMuted;
    if (sub.difficulty != null) {
      final d = sub.difficulty!.toLowerCase();
      if (d == 'easy') diffColor = AppColors.easy;
      if (d == 'medium') diffColor = AppColors.medium;
      if (d == 'hard') diffColor = AppColors.hard;
    }

    final timeStr = DateFormat('h:mm a').format(sub.dateTime);

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
          // Top Row: Teammate Identity + Submission Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              _buildAvatar(teammate),
              const SizedBox(width: 10),

              // Teammate Name & Handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teammate.effectiveName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '@${teammate.username}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Submission Time (e.g. "3:45 PM") + relative time
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurfaceElevated,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      sub.relativeTime,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Problem Title
          Text(
            sub.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Row: Status, Difficulty & Open Problem Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Status badge (if returned by data source)
                  if (sub.statusDisplay != null &&
                      sub.statusDisplay!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.easyTransparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.easy.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 11, color: AppColors.easy),
                          const SizedBox(width: 4),
                          Text(
                            sub.statusDisplay!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.easy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Difficulty badge (when real data provides it, else honest label)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        fontWeight: FontWeight.w600,
                        color: sub.difficulty != null
                            ? diffColor
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              // "Open" action
              TextButton(
                onPressed: () => _openProblem(
                  context,
                  sub.titleSlug,
                  title: sub.title,
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  minimumSize: const Size(0, 28),
                ),
                child: const Row(
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
                    Icon(Icons.arrow_outward,
                        size: 13, color: AppColors.primary),
                  ],
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
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          avatar,
          width: 36,
          height: 36,
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final Teammate teammate;
  final LeetCodeSubmission submission;

  const _ActivityItem({required this.teammate, required this.submission});
}
