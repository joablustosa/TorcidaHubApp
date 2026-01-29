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
  String? _loadError;
  /// Quantos comentários (pais) exibir inicialmente; aumentar ao tocar em "Ver mais".
  static const int _initialVisibleCount = 3;
  static const int _loadMoreCount = 5;
  int _visibleCount = _initialVisibleCount;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // 1. Buscar comentários sem join (evita erro de relação no Supabase)
      final response = await SupabaseService.client
          .from('post_comments')
          .select('id, post_id, user_id, content, parent_id, created_at')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (response == null) {
        setState(() => _comments = []);
        return;
      }

      final List<dynamic> data = response as List;
      if (data.isEmpty) {
        setState(() => _comments = []);
        return;
      }

      // 2. Buscar perfis dos autores (user_ids únicos)
      final userIds = <String>{};
      for (var item in data) {
        final map = item as Map<String, dynamic>;
        final uid = map['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) userIds.add(uid);
      }

      final profilesMap = <String, Profile>{};
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await SupabaseService.client
              .from('profiles')
              .select('id, full_name, nickname, avatar_url, updated_at')
              .inFilter('id', userIds.toList());
          if (profilesResponse != null) {
            for (var p in profilesResponse as List) {
              final profileMap = Map<String, dynamic>.from(p as Map);
              try {
                final profile = Profile.fromJson(profileMap);
                profilesMap[profile.id] = profile;
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // 3. Buscar likes dos comentários (opcional; se falhar, segue sem)
      final likesMap = <String, List<String>>{};
      final userLikesSet = <String>{};
      final commentIds = data.map((c) => (c as Map)['id'].toString()).toList();
      if (commentIds.isNotEmpty) {
        try {
          final likesResponse = await SupabaseService.client
              .from('comment_likes')
              .select('comment_id, user_id')
              .inFilter('comment_id', commentIds);
          if (likesResponse != null) {
            for (var like in likesResponse as List) {
              final likeData = like as Map<String, dynamic>;
              final commentId = likeData['comment_id']?.toString() ?? '';
              final userId = likeData['user_id']?.toString() ?? '';
              if (commentId.isNotEmpty) {
                likesMap.putIfAbsent(commentId, () => []).add(userId);
                if (userId == _authService.userId) userLikesSet.add(commentId);
              }
            }
          }
        } catch (_) {}
      }

      // 4. Montar comentários e threads
      final parentComments = <Comment>[];
      final repliesMap = <String, List<Comment>>{};

      for (var item in data) {
        final commentData = Map<String, dynamic>.from(item as Map);
        final id = commentData['id']?.toString() ?? '';
        final userId = commentData['user_id']?.toString() ?? '';
        final parentId = commentData['parent_id']?.toString();
        final createdAtRaw = commentData['created_at'];
        DateTime createdAt = DateTime.now();
        if (createdAtRaw != null) {
          if (createdAtRaw is String) {
            createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
          } else if (createdAtRaw is DateTime) {
            createdAt = createdAtRaw;
          }
        }

        final comment = Comment(
          id: id,
          postId: commentData['post_id']?.toString() ?? '',
          userId: userId,
          content: commentData['content']?.toString() ?? '',
          parentId: parentId != null && parentId.isNotEmpty ? parentId : null,
          createdAt: createdAt,
          author: profilesMap[userId],
          likesCount: likesMap[id]?.length ?? 0,
          userLiked: userLikesSet.contains(id),
        );

        if (comment.parentId == null || comment.parentId!.isEmpty) {
          parentComments.add(comment);
        } else {
          repliesMap.putIfAbsent(comment.parentId!, () => []).add(comment);
        }
      }

      // 5. Atribuir replies aos pais
      final parentCommentsWithReplies = parentComments.map((parent) {
        final replies = repliesMap[parent.id] ?? [];
        return Comment(
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
      }).toList();

        setState(() {
          _comments = parentCommentsWithReplies;
          _visibleCount = _initialVisibleCount;
        });
    } catch (e) {
      print('Erro ao carregar comentários: $e');
      setState(() {
        _loadError = e.toString();
      });
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao comentar: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
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
    final visibleComments = _comments.length > _visibleCount
        ? _comments.sublist(0, _visibleCount)
        : _comments;
    final hasMore = _comments.length > _visibleCount;
    final remainingCount = _comments.length - _visibleCount;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha sutil que integra ao card (estilo Instagram)
          Divider(height: 1, color: AppColors.textSecondary.withOpacity(0.12)),
          const SizedBox(height: 8),
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
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erro ao carregar comentários.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loadError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadComments,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Tentar novamente'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Nenhum comentário ainda.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleComments.length,
              itemBuilder: (context, index) {
                return _buildCommentItem(visibleComments[index], false);
              },
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _visibleCount = (_visibleCount + _loadMoreCount)
                          .clamp(0, _comments.length);
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(
                      remainingCount > 0
                          ? 'Ver mais comentários ($remainingCount)'
                          : 'Ver mais comentários',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],

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


