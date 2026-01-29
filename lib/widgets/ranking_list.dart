import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RankingList extends StatelessWidget {
  final String fanClubId;
  final String? currentUserId;
  final int limit;

  const RankingList({
    super.key,
    required this.fanClubId,
    this.currentUserId,
    this.limit = 20,
  });

  Widget _getRankIcon(int position) {
    switch (position) {
      case 1:
        return Icon(Icons.emoji_events, color: Colors.amber[700], size: 24);
      case 2:
        return Icon(Icons.workspace_premium, color: Colors.grey[400], size: 24);
      case 3:
        return Icon(Icons.military_tech, color: Colors.brown[600], size: 24);
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
    }
  }

  String _getBadgeLabel(String badgeLevel) {
    switch (badgeLevel) {
      case 'bronze':
        return 'Bronze';
      case 'prata':
        return 'Prata';
      case 'ouro':
        return 'Ouro';
      case 'diamante':
        return 'Diamante';
      default:
        return badgeLevel;
    }
  }

  Color _getBadgeColor(String badgeLevel) {
    switch (badgeLevel) {
      case 'bronze':
        return Colors.brown;
      case 'prata':
        return Colors.grey;
      case 'ouro':
        return Colors.amber;
      case 'diamante':
        return Colors.cyan;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingMember>>(
      future: GamificationService.getRanking(fanClubId, limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar ranking',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.emoji_events, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum membro no ranking ainda',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isCurrentUser = member.userId == currentUserId;
            final displayName = member.nickname ?? member.fullName;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: isCurrentUser
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  // Posição
                  SizedBox(
                    width: 32,
                    child: _getRankIcon(member.position),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: member.avatarUrl != null
                        ? CachedNetworkImageProvider(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? Text(
                            displayName.substring(0, 2).toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Nome e badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCurrentUser
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'você',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getBadgeColor(member.badgeLevel)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getBadgeColor(member.badgeLevel)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getBadgeLabel(member.badgeLevel),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getBadgeColor(member.badgeLevel),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${member.points} pts',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

