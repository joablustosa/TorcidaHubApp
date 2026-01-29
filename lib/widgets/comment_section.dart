import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../constants/app_colors.dart';
import '../models/supabase_models.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? parentId;
  final DateTime createdAt;
  final Profile? author;
  final List<Comment> replies;
  final int likesCount;
  final bool userLiked;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.parentId,
    required this.createdAt,
    this.author,
    this.replies = const [],
    this.likesCount = 0,
    this.userLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    Profile? author;
    if (json['profiles'] != null) {
      author = Profile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      parentId: json['parent_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: author,
      likesCount: json['likes_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
    );
  }
}

class CommentSection extends StatefulWidget {
  final String postId;
  final String fanClubId;
  final bool canModerateComments;
  final VoidCallback? onNewComment;

  const CommentSection({
    super.key,
    required this.postId,
    required this.fanClubId,
    this.canModerateComments = false,
    this.onNewComment,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _authService = AuthServiceSupabase();
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseService.client
          .from('post_comments')
          .select('''
            *,
            profiles!inner (
              id,
              full_name,
              nickname,
              avatar_url,
              updated_at
            )
          ''')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (response != null) {
        final List<dynamic> data = response as List;
        
        // Buscar likes
        final commentIds = data.map((c) => (c as Map)['id'] as String).toList();
        final likesResponse = await SupabaseService.client
            .from('comment_likes')
            .select('comment_id, user_id')
            .inFilter('comment_id', commentIds);

        final likesMap = <String, List<String>>{};
        final userLikesSet = <String>{};

        if (likesResponse != null) {
          for (var like in likesResponse as List) {
            final likeData = like as Map<String, dynamic>;
            final commentId = likeData['comment_id'] as String;
            final userId = likeData['user_id'] as String;

            likesMap.putIfAbsent(commentId, () => []).add(userId);
            if (userId == _authService.userId) {
              userLikesSet.add(commentId);
            }
          }
        }

        // Organizar em threads
        final parentComments = <Comment>[];
        final repliesMap = <String, List<Comment>>{};

        for (var item in data) {
          final commentData = Map<String, dynamic>.from(item);
          final parentId = commentData['parent_id'] as String?;
          
          final comment = Comment(
            id: commentData['id'] as String,
            postId: commentData['post_id'] as String,
            userId: commentData['user_id'] as String,
            content: commentData['content'] as String,
            parentId: parentId,
            createdAt: DateTime.parse(commentData['created_at'] as String),
            author: commentData['profiles'] != null
                ? Profile.fromJson(Map<String, dynamic>.from(commentData['profiles']))
                : null,
            likesCount: likesMap[commentData['id']]?.length ?? 0,
            userLiked: userLikesSet.contains(commentData['id']),
          );

          if (parentId == null) {
            parentComments.add(comment);
          } else {
            repliesMap.putIfAbsent(parentId, () => []).add(comment);
          }
        }

        // Adicionar replies aos parents
        for (var parent in parentComments) {
          final replies = repliesMap[parent.id] ?? [];
          parent = Comment(
            id: parent.id,
            postId: parent.postId,
            userId: parent.userId,
            content: parent.content,
            parentId: parent.parentId,
            createdAt: parent.createdAt,
            author: parent.author,
            replies: replies,
            likesCount: parent.likesCount,
            userLiked: parent.userLiked,
          );
        }

        setState(() {
          _comments = parentComments;
        });
      }
    } catch (e) {
      print('Erro ao carregar comentários: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _authService.userId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await SupabaseService.client.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': _authService.userId,
        'content': _commentController.text.trim(),
        'parent_id': _replyingToId,
      });

      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });

      await _loadComments();
      widget.onNewComment?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentário adicionado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao comentar: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _likeComment(Comment comment) async {
    if (_authService.userId == null) return;

    try {
      if (comment.userLiked) {
        await SupabaseService.client
            .from('comment_likes')
            .delete()
            .eq('comment_id', comment.id)
            .eq('user_id', _authService.userId!);
      } else {
        await SupabaseService.client.from('comment_likes').insert({
          'comment_id': comment.id,
          'user_id': _authService.userId!,
        });
      }

      await _loadComments();
    } catch (e) {
      print('Erro ao curtir comentário: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await SupabaseService.client
          .from('post_comments')
          .delete()
          .eq('id', commentId);

      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentário removido'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora';
        }
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista de comentários
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Nenhum comentário ainda.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                return _buildCommentItem(_comments[index], false);
              },
            ),

          // Indicador de resposta
          if (_replyingToName != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Respondendo a $_replyingToName',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _replyingToId = null;
                        _replyingToName = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Formulário de comentário
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyingToName != null
                        ? 'Responder a $_replyingToName...'
                        : 'Adicione um comentário...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: null,
                ),
              ),
              TextButton(
                onPressed: _isSubmitting ? null : _submitComment,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'Publicar',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, bool isReply) {
    final displayName = comment.author?.nickname ?? 
                       comment.author?.fullName ?? 
                       'Usuário';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReply)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            CircleAvatar(
              radius: isReply ? 10 : 12,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: comment.author?.avatarUrl != null
                  ? CachedNetworkImageProvider(comment.author!.avatarUrl!)
                  : null,
              child: comment.author?.avatarUrl == null
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: isReply ? 10 : 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: isReply ? 12 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: isReply ? 12 : 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _likeComment(comment),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              comment.userLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: comment.userLiked
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                            if (comment.likesCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likesCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isReply) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _replyingToId = comment.id;
                              _replyingToName = displayName;
                            });
                          },
                          child: Text(
                            'Responder',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (comment.userId == _authService.userId) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => _deleteComment(comment.id),
                          child: Text(
                            'Excluir',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                      if (widget.canModerateComments &&
                          comment.userId != _authService.userId) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => _deleteComment(comment.id),
                          child: Text(
                            'Moderar',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Replies
        if (comment.replies.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...comment.replies.map((reply) => _buildCommentItem(reply, true)),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}


