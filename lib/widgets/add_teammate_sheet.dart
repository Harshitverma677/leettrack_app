import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/teammate_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class AddTeammateSheet extends StatefulWidget {
  const AddTeammateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTeammateSheet(),
    );
  }

  @override
  State<AddTeammateSheet> createState() => _AddTeammateSheetState();
}

class _AddTeammateSheetState extends State<AddTeammateSheet> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a LeetCode username';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<TeammateRepository>();
      await repo.addTeammate(
        username,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.easy, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Added @$username to leaderboard!',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final errStr = e.toString();
          if (errStr.contains('Exception:')) {
            _errorMessage = errStr.replaceFirst('Exception: ', '');
          } else {
            _errorMessage = errStr;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: AppDimensions.paddingL,
        left: AppDimensions.paddingXL,
        right: AppDimensions.paddingXL,
        bottom: AppDimensions.paddingXXL + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXL),
        ),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title & Subtitle
            const Text(
              'Add Teammate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sync real stats directly from LeetCode',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 22),

            // Error banner if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.hardTransparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: AppColors.hard.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.hard,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.hard,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // LeetCode Username Field
            const Text(
              'LeetCode Username',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. tour_list or neetcode',
                prefixIcon: Icon(
                  Icons.alternate_email,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 16),

            // Display Name (Optional) Field
            const Text(
              'Display Name (Optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _displayNameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. Alice or Bob',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textDark,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textDark,
                      ),
                    )
                  : const Text(
                      'Verify & Add to Leaderboard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
