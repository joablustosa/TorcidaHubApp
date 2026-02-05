import '../services/supabase_service.dart';
import '../models/supabase_models.dart';

class PostService {
  static Future<List<Post>> getPosts({
    required String fanClubId,
    int limit = 10,
    int offset = 0,
    String? currentUserId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('posts')
          .select('*')
          .eq('fan_club_id', fanClubId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>;
      List<Post> posts = [];

      for (var item in data) {
        final postData = Map<String, dynamic>.from(item);
        
        // Buscar autor
        try {
          final authorResponse = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', postData['author_id'].toString())
              .maybeSingle();
          
          if (authorResponse != null) {
            postData['profiles'] = authorResponse;
          }
        } catch (e) {
          print('Erro ao buscar autor: $e');
        }

        // Buscar likes
        try {
          final likesResponse = await SupabaseService.client
              .from('post_likes')
              .select('user_id')
              .eq('post_id', postData['id'].toString());

          final likesList = likesResponse as List? ?? [];
          postData['likes_count'] = likesList.length;
          postData['user_liked'] = currentUserId != null &&
              likesList.any((e) => (e as Map)['user_id'] == currentUserId);
        } catch (e) {
          print('Erro ao buscar likes: $e');
        }

        // Buscar comentários
        try {
          final commentsResponse = await SupabaseService.client
              .from('post_comments')
              .select('id')
              .eq('post_id', postData['id'].toString());
          
          postData['comments_count'] = (commentsResponse as List? ?? []).length;
        } catch (e) {
          print('Erro ao buscar comentários: $e');
        }

        posts.add(Post.fromJson(postData));
      }

      return posts;
    } catch (e) {
      print('Erro ao buscar posts: $e');
      return [];
    }
  }

  static Future<Post> createPost({
    required String fanClubId,
    required String userId,
    String? content,
    String? imageUrl,
    bool allowComments = true,
    bool membersOnly = false,
  }) async {
    try {
      final postData = <String, dynamic>{
        'fan_club_id': fanClubId,
        'author_id': userId,
        'content': content ?? '',
        'image_url': imageUrl,
        'allow_comments': allowComments,
        'members_only': membersOnly,
      };

      final response = await SupabaseService.client
          .from('posts')
          .insert(postData)
          .select()
          .single();

      return Post.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      print('Erro ao criar post: $e');
      rethrow;
    }
  }

  static Future<void> likePost(String postId, String userId) async {
    try {
      await SupabaseService.client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } catch (e) {
      print('Erro ao curtir post: $e');
      rethrow;
    }
  }

  static Future<void> unlikePost(String postId, String userId) async {
    try {
      await SupabaseService.client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erro ao descurtir post: $e');
      rethrow;
    }
  }

  static Future<int> getLikesCount(String postId) async {
    try {
      final response = await SupabaseService.client
          .from('post_likes')
          .select('id')
          .eq('post_id', postId);

      final list = response as List;
      return list.length;
    } catch (e) {
      print('Erro ao contar likes: $e');
      return 0;
    }
  }

  static Future<bool> hasUserLiked(String postId, String userId) async {
    try {
      final response = await SupabaseService.client
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Erro ao verificar like: $e');
      return false;
    }
  }

  static Future<void> deletePost(String postId) async {
    try {
      await SupabaseService.client.from('posts').delete().eq('id', postId);
    } catch (e) {
      print('Erro ao deletar post: $e');
      rethrow;
    }
  }

  static Future<void> pinPost(String postId, bool pinned) async {
    try {
      await SupabaseService.client
          .from('posts')
          .update({'is_pinned': pinned})
          .eq('id', postId);
    } catch (e) {
      print('Erro ao fixar post: $e');
      rethrow;
    }
  }
}

