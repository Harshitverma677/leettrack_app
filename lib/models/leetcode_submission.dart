import 'package:intl/intl.dart';

class LeetCodeSubmission {
  final String title;
  final String titleSlug;
  final int timestamp; // epoch seconds
  final String? statusDisplay;
  final String? difficulty;

  const LeetCodeSubmission({
    required this.title,
    required this.titleSlug,
    required this.timestamp,
    this.statusDisplay,
    this.difficulty,
  });

  String get problemUrl => 'https://leetcode.com/problems/$titleSlug/';

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  String get formattedSolvedDate {
    return 'Solved on ${DateFormat('MMM d').format(dateTime)}';
  }

  String get formattedMonthDay {
    final now = DateTime.now();
    if (dateTime.year != now.year) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
    return DateFormat('MMM d').format(dateTime);
  }

  bool get isWithinPastSevenDays {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return dateTime.isAfter(sevenDaysAgo);
  }

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()} year${diff.inDays >= 730 ? "s" : ""} ago';
    } else if (diff.inDays >= 30) {
      return '${(diff.inDays / 30).floor()} month${diff.inDays >= 60 ? "s" : ""} ago';
    } else if (diff.inDays >= 7) {
      return '${(diff.inDays / 7).floor()} week${diff.inDays >= 14 ? "s" : ""} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? "s" : ""} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? "s" : ""} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? "s" : ""} ago';
    } else {
      return 'Just now';
    }
  }

  LeetCodeSubmission copyWith({
    String? title,
    String? titleSlug,
    int? timestamp,
    String? statusDisplay,
    String? difficulty,
  }) {
    return LeetCodeSubmission(
      title: title ?? this.title,
      titleSlug: titleSlug ?? this.titleSlug,
      timestamp: timestamp ?? this.timestamp,
      statusDisplay: statusDisplay ?? this.statusDisplay,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  factory LeetCodeSubmission.fromJson(Map<String, dynamic> json) {
    int parsedTimestamp = 0;
    final rawTs = json['timestamp'];
    if (rawTs is int) {
      parsedTimestamp = rawTs;
    } else if (rawTs is String) {
      parsedTimestamp = int.tryParse(rawTs) ?? 0;
    }

    return LeetCodeSubmission(
      title: json['title']?.toString() ?? 'Unknown Problem',
      titleSlug: json['titleSlug']?.toString() ?? '',
      timestamp: parsedTimestamp,
      statusDisplay: json['statusDisplay']?.toString(),
      difficulty: json['difficulty']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'titleSlug': titleSlug,
        'timestamp': timestamp,
        'statusDisplay': statusDisplay,
        'difficulty': difficulty,
      };
}
