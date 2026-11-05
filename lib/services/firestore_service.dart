import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leetcode_profile.dart';
import '../models/teammate.dart';

class FirestoreService {
  final FirebaseFirestore? _customFirestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _membersRef(String uid) =>
      _usersRef.doc(uid).collection('members');

  /// Fetch user document by UID
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    try {
      final snapshot = await _usersRef.doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }
      return snapshot.data();
    } catch (e) {
      throw Exception('Failed to load user account from Firestore: $e');
    }
  }

  /// Create initial user account record upon registration
  Future<void> createUserAccount({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    try {
      await _usersRef.doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': displayName?.trim() ?? '',
        'primaryProfileSetupComplete': false,
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to create user record in cloud: $e');
    }
  }

  /// Save or update validated primary LeetCode profile
  Future<void> savePrimaryProfile({
    required String uid,
    required String username,
    required LeetCodeProfile profile,
  }) async {
    final displayUsername =
        profile.username.isNotEmpty ? profile.username : username.trim();
    final normalizedUsername = displayUsername.toLowerCase().trim();

    try {
      await _usersRef.doc(uid).set({
        'uid': uid,
        'primaryLeetCodeUsername': displayUsername,
        'primaryLeetCodeUsernameNormalized': normalizedUsername,
        'primaryLeetCodeProfile': profile.toJson(),
        'primaryProfileSetupComplete': true,
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save primary profile to Firestore: $e');
    }
  }

  /// Fetch all members for a given user account
  Future<List<Teammate>> getMembers(String uid) async {
    try {
      final snapshot =
          await _membersRef(uid).orderBy('createdAt', descending: false).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final rawProfile = data['profile'];
        LeetCodeProfile? profile;
        if (rawProfile is Map<String, dynamic>) {
          profile = LeetCodeProfile.fromJson(rawProfile);
        } else if (rawProfile is Map) {
          profile = LeetCodeProfile.fromJson(Map<String, dynamic>.from(rawProfile));
        }

        DateTime? lastUpdated;
        final ts = data['updatedAt'] ?? data['createdAt'];
        if (ts is Timestamp) {
          lastUpdated = ts.toDate();
        }

        return Teammate(
          username: data['leetCodeUsername']?.toString() ??
              data['username']?.toString() ??
              '',
          displayName: data['displayName']?.toString(),
          avatarUrl: data['avatarUrl']?.toString() ?? profile?.userAvatar,
          profile: profile,
          lastUpdated: lastUpdated,
          isCurrentUser: false,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to load team members from cloud: $e');
    }
  }

  /// Add member to user's members subcollection
  Future<void> addMember({
    required String uid,
    required String username,
    String? displayName,
    required LeetCodeProfile profile,
  }) async {
    final displayUsername =
        profile.username.isNotEmpty ? profile.username : username.trim();
    final normalized = displayUsername.toLowerCase().trim();
    final docRef = _membersRef(uid).doc(normalized);

    try {
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        throw Exception('Teammate @$displayUsername is already on your leaderboard');
      }

      await docRef.set({
        'memberId': normalized,
        'ownerUid': uid,
        'leetCodeUsername': displayUsername,
        'leetCodeUsernameNormalized': normalized,
        'displayName': displayName?.trim(),
        'avatarUrl': profile.userAvatar,
        'profile': profile.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Cloud storage error: ${e.message ?? e.code}');
    } catch (e) {
      if (e.toString().contains('already on your leaderboard')) {
        rethrow;
      }
      throw Exception('Failed to add teammate to cloud: $e');
    }
  }

  /// Remove a member by username
  Future<void> removeMember(String uid, String username) async {
    final normalized = username.toLowerCase().trim();
    try {
      await _membersRef(uid).doc(normalized).delete();
    } catch (e) {
      throw Exception('Failed to remove teammate from cloud: $e');
    }
  }

  /// Wipe all members for a user
  Future<int> wipeMembers(String uid) async {
    try {
      final snapshot = await _membersRef(uid).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to wipe teammates from cloud: $e');
    }
  }
}
