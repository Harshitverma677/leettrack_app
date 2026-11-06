class DailyChallenge {
  final String date;
  final String title;
  final String titleSlug;
  final String difficulty;
  final String topic;
  final List<String> topics;
  final String link;

  const DailyChallenge({
    required this.date,
    required this.title,
    required this.titleSlug,
    required this.difficulty,
    required this.topic,
    this.topics = const [],
    required this.link,
  });

  bool get isValid =>
      title.trim().isNotEmpty &&
      (link.trim().isNotEmpty || titleSlug.trim().isNotEmpty);

  String get fullProblemUrl {
    final trimmedLink = link.trim();
    if (trimmedLink.isNotEmpty) {
      return trimmedLink.startsWith('http')
          ? trimmedLink
          : 'https://leetcode.com$trimmedLink';
    }
    final slug = titleSlug.trim();
    if (slug.isNotEmpty) {
      return 'https://leetcode.com/problems/$slug/';
    }
    return '';
  }

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('activeDailyCodingChallengeQuestion')) {
      final active = json['activeDailyCodingChallengeQuestion'];
      if (active == null) {
        throw Exception('Daily challenge data is missing');
      }

      final date = active['date']?.toString() ?? '';
      final rawLink = active['link']?.toString() ?? '';
      final q = active['question'] as Map<String, dynamic>? ?? {};

      final title = q['title']?.toString() ?? '';
      final titleSlug = q['titleSlug']?.toString() ?? '';
      final difficulty = q['difficulty']?.toString() ?? 'Medium';

      final List<String> parsedTopics = [];
      final topicTags = q['topicTags'] as List<dynamic>?;
      if (topicTags != null) {
        for (final item in topicTags) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString();
            if (name != null && name.trim().isNotEmpty) {
              parsedTopics.add(name.trim());
            }
          }
        }
      }

      final String topic =
          parsedTopics.isNotEmpty ? parsedTopics.first : 'Algorithms';

      String computedLink = '';
      if (rawLink.isNotEmpty) {
        computedLink = rawLink.startsWith('http')
            ? rawLink
            : 'https://leetcode.com$rawLink';
      } else if (titleSlug.isNotEmpty) {
        computedLink = 'https://leetcode.com/problems/$titleSlug/';
      }

      return DailyChallenge(
        date: date,
        title: title,
        titleSlug: titleSlug,
        difficulty: difficulty,
        topic: topic,
        topics: parsedTopics.isNotEmpty ? parsedTopics : [topic],
        link: computedLink,
      );
    } else {
      // Direct stored map from local cache
      final rawTopics = json['topics'] as List<dynamic>?;
      final parsedTopics = rawTopics != null
          ? rawTopics.map((e) => e.toString()).toList()
          : <String>[];
      final topic = json['topic']?.toString() ??
          (parsedTopics.isNotEmpty ? parsedTopics.first : 'Algorithms');

      return DailyChallenge(
        date: json['date']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        titleSlug: json['titleSlug']?.toString() ?? '',
        difficulty: json['difficulty']?.toString() ?? 'Medium',
        topic: topic,
        topics: parsedTopics.isNotEmpty ? parsedTopics : (topic.isNotEmpty ? [topic] : []),
        link: json['link']?.toString() ?? '',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'title': title,
        'titleSlug': titleSlug,
        'difficulty': difficulty,
        'topic': topic,
        'topics': topics,
        'link': link,
      };
}
