import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/comment.dart';
import 'package:mychatolic_app/models/profile.dart';

class SocialService {
  final _supabase = Supabase.instance.client;

  // --- REAL-TIME POST STREAM (EVENT BUS) ---
  static final StreamController<UserPost> _postStream = StreamController.broadcast();
  static Stream<UserPost> get postUpdateStream => _postStream.stream;

  static void broadcastPostUpdate(UserPost post) {
    if (!_postStream.isClosed) {
       _postStream.add(post);
    }
  }

  // Helper
  User? get currentUser => _supabase.auth.currentUser;

  // 1. Fetch Single Post by ID
  Future<UserPost?> fetchPostById(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    try {
      // 1. Fetch Post Data
      final postData = await _supabase.from('posts').select().eq('id', postId).single();
      
      // 2. Fetch Author Profile
      final authorId = postData['user_id'];
      final authorData = await _supabase.from('profiles').select().eq('id', authorId).single();
      final authorProfile = Profile(
        id: authorId, 
        fullName: authorData['full_name'] ?? 'Umat', 
        avatarUrl: authorData['avatar_url'], 
        role: authorData['role'] ?? 'Umat'
      );

      // 3. Fetch Counts & Status
      final likesCount = await _supabase.from('post_likes').count().eq('post_id', postId);
      final commentsCount = await _supabase.from('post_comments').count().eq('post_id', postId);
      
      bool isLiked = false;
      if (userId != null) {
        final likeCheck = await _supabase.from('post_likes').select('id').eq('post_id', postId).eq('user_id', userId).maybeSingle();
        isLiked = likeCheck != null;
      }

      return UserPost(
        id: postData['id'].toString(),
        userId: authorId,
        caption: postData['caption'],
        imageUrl: postData['image_url'],
        type: postData['type'] ?? 'text',
        createdAt: DateTime.tryParse(postData['created_at'].toString()) ?? DateTime.now(),
        likesCount: likesCount,
        commentsCount: commentsCount,
        isLikedByMe: isLiked,
        author: authorProfile,
      );
    } catch (e) {
      print("Error fetching single post: $e");
      return null;
    }
  }

  // 2. Fetch Posts RPC
  Future<List<UserPost>> fetchPosts({
    String? filterType, 
    String? filterId, 
    String? userId,
    int page = 0,
    int limit = 20,
  }) async {
    // Use passed userId or fallback to current authenticated user
    final currentUserId = userId ?? _supabase.auth.currentUser?.id;
    print("Fetching posts via RPC... User: $currentUserId, Page: $page");

    try {
      final Map<String, dynamic> params = {
        'p_user_id': currentUserId,
        'p_filter_type': filterType,
        'p_filter_id': filterId,
        'p_limit': limit,
        'p_offset': page * limit,
      };

      final response = await _supabase.rpc('get_posts_with_status', params: params);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
         // Correct Mapping based on user request
         final authorProfile = Profile(
            id: json['user_id']?.toString() ?? '',
            fullName: json['author_full_name'] ?? 'Umat', 
            avatarUrl: json['author_avatar_url'], 
            role: json['author_role'] ?? 'Umat',
         );

         return UserPost(
           id: json['id'].toString(),
           userId: json['user_id'].toString(),
           caption: json['caption'],
           imageUrl: json['image_url'],
           type: json['type'] ?? 'text',
           createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
           likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
           commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
           isLikedByMe: json['is_liked_by_me'] ?? false, 
           author: authorProfile,
         );
      }).toList();

    } catch (e, stackTrace) {
      print("RPC FETCH ERROR: $e");
      print(stackTrace);
      throw Exception('Failed to fetch posts: $e');
    }
  }

  // 3. Create Post
  Future<void> createPost({
    required String content, 
    String? imageUrl, 
    required String type,
    String? countryId,
    String? dioceseId,
    String? churchId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').insert({
        'user_id': user.id,
        'caption': content,
        'image_url': imageUrl,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
        'country_id': countryId,
        'diocese_id': dioceseId,
        'church_id': churchId,
      });
    } catch (e) {
      throw Exception("Post creation failed: $e");
    }
  }

  // 4. Upload Post Image
  Future<String> uploadPostImage(File image) async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      try {
        await _supabase.storage.from('post_images').upload(
          fileName,
          image,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        return _supabase.storage.from('post_images').getPublicUrl(fileName);
      } catch (e) {
        throw Exception("Image upload failed: $e");
      }
  }

  // 5. Toggle Like
  Future<bool> toggleLike(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final check = await _supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (check != null) {
        await _supabase.from('post_likes').delete().eq('id', check['id']);
        return false;
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
        return true;
      }
    } catch (e) {
      throw Exception("Toggle like failed: $e");
    }
  }

  // 6. Fetch Comments
  Future<List<Comment>> fetchComments(String postId) async {
    final currentUser = _supabase.auth.currentUser;

    try {
      final response = await _supabase
          .from('post_comments')
          .select('*, profiles(*), comment_likes(user_id)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      
      final data = response as List<dynamic>;

      final List<Comment> allComments = [];
      for (var json in data) {
        try {
          final likesList = json['comment_likes'] as List<dynamic>? ?? [];
          final isLiked = currentUser != null && likesList.any((l) => l['user_id'] == currentUser.id);

          final map = Map<String, dynamic>.from(json);
          map['likes_count'] = likesList.length;
          map['is_liked_by_me'] = isLiked;
          
          final comment = Comment.fromJson(map);
          allComments.add(comment);
        } catch (e) {
          print("Error parsing comment: $e");
        }
      }

      final Map<String, List<Comment>> childrenMap = {};
      for (var c in allComments) {
        if (c.parentId != null) {
          if (!childrenMap.containsKey(c.parentId!)) {
            childrenMap[c.parentId!] = [];
          }
          childrenMap[c.parentId!]!.add(c);
        }
      }

      Comment buildTree(Comment c) {
        final children = childrenMap[c.id] ?? [];
        return Comment(
          id: c.id,
          userId: c.userId,
          content: c.content,
          createdAt: c.createdAt,
          author: c.author,
          parentId: c.parentId,
          replies: children.map((child) => buildTree(child)).toList(),
          likesCount: c.likesCount,
          isLikedByMe: c.isLikedByMe,
        );
      }

      final List<Comment> rootComments = [];
      for (var c in allComments) {
        if (c.parentId == null) {
          rootComments.add(buildTree(c));
        }
      }
      return rootComments;

    } catch (e, stack) {
      print("Failed to fetch comments: $e");
      print(stack);
      return [];
    }
  }

  // 7. Add Comment
  Future<void> addComment(String postId, String content, {String? parentId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'parent_id': parentId,
      });
    } catch (e) {
      throw Exception("Failed to add comment: $e");
    }
  }

  // 8. Toggle Comment Like
  Future<bool> toggleCommentLike(String commentId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
       final check = await _supabase
           .from('comment_likes')
           .select('id')
           .eq('comment_id', commentId)
           .eq('user_id', user.id)
           .maybeSingle();

       if (check != null) {
         await _supabase.from('comment_likes').delete().eq('id', check['id']);
         return false; 
       } else {
         await _supabase.from('comment_likes').insert({
           'comment_id': commentId,
           'user_id': user.id,
         });
         return true;
       }
    } catch (e) {
      throw Exception("Like comment failed: $e");
    }
  }

  // 9. Report Comment
  Future<void> reportComment(String commentId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    try {
      await _supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
       throw Exception("Report comment failed: $e");
    }
  }

  // 10. Report Post
  Future<void> reportPost(String postId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_reports').insert({
        'post_id': postId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Report failed: $e");
    }
  }

  // 11. Delete Post
  Future<void> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception("Delete failed: $e");
    }
  }
}
