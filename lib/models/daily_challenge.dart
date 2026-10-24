class DailyChallenge {
  final String date;
  final String title;
  final String titleSlug;
  final String difficulty;
  final String topic;
  final String link;

  const DailyChallenge({
    required this.date,
    required this.title,
    required this.titleSlug,
    required this.difficulty,
    required this.topic,
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

    String topic = 'Algorithms';
    final topics = q['topicTags'] as List<dynamic>?;
    if (topics != null && topics.isNotEmpty) {
      final firstTopic = topics.first as Map<String, dynamic>?;
      topic = firstTopic?['name']?.toString() ?? 'Algorithms';
    }

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
      link: computedLink,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'title': title,
        'titleSlug': titleSlug,
        'difficulty': difficulty,
        'topic': topic,
        'link': link,
      };
}
