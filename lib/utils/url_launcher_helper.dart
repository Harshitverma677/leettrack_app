import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Opens a real LeetCode URL in the device's external browser.
  /// Reports errors via SnackBar and provides a retry action on failure.
  static Future<bool> openLeetCodeUrl(
    BuildContext context,
    String? rawUrl, {
    String? fallbackTitle,
  }) async {
    final trimmed = rawUrl?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LeetCode link is unavailable for this item'),
          ),
        );
      }
      return false;
    }

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        uri = Uri.parse('https://leetcode.com$trimmed');
      }
    } catch (_) {
      uri = null;
    }

    if (uri == null || !uri.hasAuthority) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid LeetCode URL: $trimmed'),
          ),
        );
      }
      return false;
    }

    try {
      // Direct external browser launch
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to platform default if external application returned false
        final fallbackLaunched = await launchUrl(uri);
        if (!fallbackLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open browser for: ${uri.toString()}'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => openLeetCodeUrl(context, rawUrl,
                    fallbackTitle: fallbackTitle),
              ),
            ),
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link in browser: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => openLeetCodeUrl(context, rawUrl,
                  fallbackTitle: fallbackTitle),
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Opens a LeetCode problem directly by its titleSlug.
  static Future<bool> openProblemBySlug(
    BuildContext context,
    String? titleSlug, {
    String? title,
  }) async {
    final slug = titleSlug?.trim() ?? '';
    if (slug.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              title != null && title.isNotEmpty
                  ? 'Problem URL slug unavailable for "$title"'
                  : 'Problem URL slug is unavailable',
            ),
          ),
        );
      }
      return false;
    }

    final url = 'https://leetcode.com/problems/$slug/';
    return openLeetCodeUrl(context, url, fallbackTitle: title);
  }
}
