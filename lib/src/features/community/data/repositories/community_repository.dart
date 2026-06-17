import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../user/models/user_model.dart';
import '../../domain/models/challenge_model.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/post_model.dart';

final communityRepositoryProvider = Provider((ref) => CommunityRepository());

class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Post>> getPostsStream(String gymId, {int limit = 30}) {
    return _firestore
        .collection('communityPosts')
        .where('gymId', isEqualTo: gymId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  Future<void> createPost(Post post, {File? imageFile}) async {
    try {
      String? imageUrl;

      if (imageFile != null) {
        final ref = _storage.ref().child(
          'gyms/${post.gymId}/community_posts/${post.id}.jpg',
        );
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      final postToSave = post.copyWith(imageUrl: imageUrl);

      // Use a batch to atomically write the post and update the user's
      // lastPostAt timestamp.  The Firestore security rule for communityPosts
      // checks users/{uid}.lastPostAt to enforce a 60-second cooldown between
      // posts (prevents spam flooding the gym feed).
      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('communityPosts').doc(post.id),
        postToSave.toFirestore(),
      );

      // Stamp the author's lastPostAt so the rule can verify the cooldown.
      batch.update(
        _firestore.collection('users').doc(post.userId),
        {'lastPostAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<void> updatePostContent(String postId, String content) async {
    await _firestore.collection('communityPosts').doc(postId).update({
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _firestore.collection('communityPosts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final post = Post.fromFirestore(snapshot);
      final isLiked = post.likedBy.contains(userId);

      final updatedLikedBy = List<String>.from(post.likedBy);
      if (isLiked) {
        updatedLikedBy.remove(userId);
      } else {
        updatedLikedBy.add(userId);
      }

      transaction.update(docRef, {
        'likedBy': updatedLikedBy,
        'likesCount': updatedLikedBy.length,
      });
    });
  }

  Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map((doc) => Comment.fromFirestore(doc))
              .toList();
          comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return comments;
        });
  }

  Future<void> addComment(String postId, Comment comment) async {
    final postRef = _firestore.collection('communityPosts').doc(postId);
    final commentRef = postRef.collection('comments').doc(comment.id);

    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;

      final post = Post.fromFirestore(postSnapshot);

      transaction.set(commentRef, comment.toFirestore());
      transaction.update(postRef, {'commentsCount': post.commentsCount + 1});
    });
  }

  Stream<List<Challenge>> getChallengesStream(String gymId) {
    return _firestore
        .collection('challenges')
        .where('gymId', isEqualTo: gymId)
        .snapshots()
        .map((snapshot) {
          final challenges = snapshot.docs
              .map((doc) => Challenge.fromFirestore(doc))
              .toList();
          challenges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return challenges;
        });
  }

  Future<void> createChallenge(Challenge challenge) async {
    await _firestore
        .collection('challenges')
        .doc(challenge.id)
        .set(challenge.toFirestore());
  }

  Stream<List<UserModel>> getLeaderboardStream(String gymId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['uid'] ??= doc.id;
                return UserModel.fromMap(data);
              })
              .where((user) {
                return (user.role ?? '').toLowerCase() == 'player';
              })
              .toList();

          users.sort((a, b) {
            final trophyCompare = b.trophies.compareTo(a.trophies);
            if (trophyCompare != 0) return trophyCompare;
            return _displayName(a).compareTo(_displayName(b));
          });

          return users.take(limit).toList();
        });
  }

  String _displayName(UserModel user) {
    final name = [
      user.firstName,
      user.lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

    return name.trim().isNotEmpty ? name.trim().toLowerCase() : user.email;
  }
}

final postsStreamProvider = StreamProvider.family
    .autoDispose<List<Post>, String>((ref, gymId) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getPostsStream(gymId);
    });

final commentsStreamProvider = StreamProvider.family
    .autoDispose<List<Comment>, String>((ref, postId) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getCommentsStream(postId);
    });

final challengesStreamProvider = StreamProvider.family
    .autoDispose<List<Challenge>, String>((ref, gymId) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getChallengesStream(gymId);
    });

final leaderboardStreamProvider = StreamProvider.family
    .autoDispose<List<UserModel>, String>((ref, gymId) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getLeaderboardStream(gymId);
    });
