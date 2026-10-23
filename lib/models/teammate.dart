import 'leetcode_profile.dart';
import 'leetcode_submission.dart';

class Teammate {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final LeetCodeProfile? profile;
  final List<LeetCodeSubmission> recentSubmissions;
  final DateTime? lastUpdated;
  final bool isCurrentUser;

  const Teammate({
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.profile,
    this.recentSubmissions = const [],
    this.lastUpdated,
    this.isCurrentUser = false,
  });

  String get effectiveName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (profile?.realName != null && profile!.realName!.trim().isNotEmpty) {
      return profile!.realName!.trim();
    }
    return username;
  }

  String get effectiveAvatar {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl!;
    if (profile?.userAvatar != null && profile!.userAvatar!.isNotEmpty) {
      return profile!.userAvatar!;
    }
    return '';
  }

  int get totalSolved => profile?.totalSolved ?? 0;
  int get easySolved => profile?.easySolved ?? 0;
  int get mediumSolved => profile?.mediumSolved ?? 0;
  int get hardSolved => profile?.hardSolved ?? 0;
  double? get accuracy => profile?.accuracy;
  int get streak => profile?.streak ?? 0;
  bool get hasSolvedToday => profile?.hasSolvedToday ?? false;
  double? get contestRating => profile?.contestRating;

  Teammate copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    LeetCodeProfile? profile,
    List<LeetCodeSubmission>? recentSubmissions,
    DateTime? lastUpdated,
    bool? isCurrentUser,
  }) {
    return Teammate(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profile: profile ?? this.profile,
      recentSubmissions: recentSubmissions ?? this.recentSubmissions,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'profile': profile?.toJson(),
        'recentSubmissions':
            recentSubmissions.map((s) => s.toJson()).toList(),
        'lastUpdated': lastUpdated?.toIso8601String(),
        'isCurrentUser': isCurrentUser,
      };

  factory Teammate.fromJson(Map<String, dynamic> json) {
    return Teammate(
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      profile: json['profile'] != null
          ? LeetCodeProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      recentSubmissions: (json['recentSubmissions'] as List<dynamic>?)
              ?.map((e) =>
                  LeetCodeSubmission.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }
}
