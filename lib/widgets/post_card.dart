import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool isAdmin;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onLike;
  final VoidCallback? onUnlike;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onComment;
  final bool showComments;
  /// Quando false, não envolve em Card (para ser usado dentro de um Card único com comentários).
  final bool embedInCard;
  /// Post é exclusivo para assinantes.
  final bool isMembersOnly;
  /// Usuário tem permissão para ver conteúdo exclusivo (assinatura ativa).
  final bool canAccessPost;

  const PostCard({
    super.key,
    required this.post,
    this.isAdmin = false,
    this.canEdit = false,
    this.canDelete = false,
    this.onLike,
    this.onUnlike,
    this.onDelete,
    this.onEdit,
    this.onComment,
    this.showComments = false,
    this.embedInCard = true,
    this.isMembersOnly = false,
    this.canAccessPost = true,
  });

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
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = post.author?.nickname ?? post.author?.fullName ?? 'Usuário';
    final isEdited = post.updatedAt != null &&
        post.updatedAt!.isAfter(post.createdAt);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: post.author?.avatarUrl != null
                      ? CachedNetworkImageProvider(post.author!.avatarUrl!)
                      : null,
                  child: post.author?.avatarUrl == null
                      ? Text(
                          (post.author?.fullName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Nome e data
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (post.isPinned) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Fixado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isMembersOnly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium,
                                    size: 12,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Exclusivo',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDate(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• editado',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu de opções
                if (canEdit || canDelete || isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                        case 'pin':
                          // TODO: Implementar fixar/desfixar
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                      if (isAdmin)
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(post.isPinned ? 'Desfixar' : 'Fixar'),
                            ],
                          ),
                        ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Excluir', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Conteúdo (bloqueado para exclusivo sem acesso ou conteúdo normal)
          if (isMembersOnly && !canAccessPost) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.06),
                    AppColors.primary.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conteúdo Exclusivo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Disponível apenas para membros com assinatura ativa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (post.content != null && post.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  post.content!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

            // Imagem
            if (post.imageUrl != null || (post.imageUrls != null && post.imageUrls!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl ?? post.imageUrls!.first,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    height: 300,
                    color: AppColors.background,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: AppColors.background,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),

            // Ações (Like, Comment)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Like
                  InkWell(
                    onTap: post.userLiked ? onUnlike : onLike,
                    child: Row(
                      children: [
                        Icon(
                          post.userLiked ? Icons.favorite : Icons.favorite_border,
                          color: post.userLiked ? AppColors.error : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${post.likesCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Comment
                  InkWell(
                    onTap: onComment,
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${post.commentsCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Share
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      // TODO: Implementar compartilhar
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      );

    if (!embedInCard) {
      return content;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: post.isPinned
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: content,
    );
  }
}

