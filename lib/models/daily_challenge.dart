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

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    final active = json['activeDailyCodingChallengeQuestion'];
    if (active == null) {
      throw Exception('Daily challenge data is missing');
    }

    final date = active['date']?.toString() ?? '';
    final link = active['link']?.toString() ?? '';
    final q = active['question'] as Map<String, dynamic>? ?? {};

    final title = q['title']?.toString() ?? 'Daily Challenge';
    final titleSlug = q['titleSlug']?.toString() ?? '';
    final difficulty = q['difficulty']?.toString() ?? 'Medium';

    String topic = 'Algorithms';
    final topics = q['topicTags'] as List<dynamic>?;
    if (topics != null && topics.isNotEmpty) {
      final firstTopic = topics.first as Map<String, dynamic>?;
      topic = firstTopic?['name']?.toString() ?? 'Algorithms';
    }

    return DailyChallenge(
      date: date,
      title: title,
      titleSlug: titleSlug,
      difficulty: difficulty,
      topic: topic,
      link: link.startsWith('http') ? link : 'https://leetcode.com$link',
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
