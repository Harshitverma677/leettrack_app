import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _handleController = TextEditingController();
  bool _isEditingHandle = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<TeammateRepository>();
    _handleController.text = repo.currentUserHandle;
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  void _changeDailyGoal(int current) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          backgroundColor: AppColors.cardSurface,
          title: const Text(
            'Select Daily Problem Goal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [1, 2, 3, 5, 10].map((val) {
            return SimpleDialogOption(
              onPressed: () {
                context.read<TeammateRepository>().updateDailyGoal(val);
                Navigator.of(ctx).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$val problem${val > 1 ? "s" : ""} / day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: val == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: val == current
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (val == current)
                      const Icon(Icons.check,
                          color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _saveHandle() async {
    final newHandle = _handleController.text.trim();
    if (newHandle.isNotEmpty) {
      await context
          .read<TeammateRepository>()
          .updateCurrentUserHandle(newHandle);
      setState(() => _isEditingHandle = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurfaceElevated,
            content: Text(
              'Updated my handle to @$newHandle',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  void _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Reset All Local Data?'),
        content: const Text(
          'This will clear local storage and reset the teammate roster to default showcase values.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Reset', style: TextStyle(color: AppColors.hard)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<TeammateRepository>().resetAll();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TeammateRepository>();
    final dailyGoal = repo.dailyGoal;
    final handle = repo.currentUserHandle;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: AppColors.primary, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        children: [
          // Study Goals Section
          _buildSectionHeader('STUDY GOALS'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: ListTile(
              title: const Text(
                'Daily Goal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '$dailyGoal problems / day',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardSurfaceElevated,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  '$dailyGoal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              onTap: () => _changeDailyGoal(dailyGoal),
            ),
          ),

          const SizedBox(height: 24),

          // My LeetCode Handle Section
          _buildSectionHeader('MY LEETCODE HANDLE'),
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Handle',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This handle identifies "You" on the leaderboard and populates My Profile.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isEditingHandle) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _handleController,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            prefixText: '@',
                            hintText: 'LeetCode handle',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveHandle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textDark,
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@$handle',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit,
                            size: 14, color: AppColors.textSecondary),
                        label: const Text('Change',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        onPressed: () {
                          setState(() => _isEditingHandle = true);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reminders Section
          _buildSectionHeader('REMINDERS'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: ListTile(
              title: const Text(
                'Daily Practice Reminder',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Requires local notification permission',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              trailing: Switch(
                value: false,
                onChanged: null, // Disabled per instruction specification
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Account / Local Storage Section
          _buildSectionHeader('ACCOUNT & LOCAL DATA'),
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.easy),
                    SizedBox(width: 8),
                    Text(
                      'Authenticated Coder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Local-first anonymous session. No private credentials or cookies stored.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _confirmReset,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.hard),
                  label: const Text('Reset All Local Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.hard,
                    side: const BorderSide(color: AppColors.hard, width: 1),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
