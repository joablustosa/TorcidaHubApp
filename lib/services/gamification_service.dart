import '../services/supabase_service.dart';

class RankingMember {
  final String id;
  final String userId;
  final String fullName;
  final String? nickname;
  final String? avatarUrl;
  final int points;
  final String badgeLevel;
  final int position;

  RankingMember({
    required this.id,
    required this.userId,
    required this.fullName,
    this.nickname,
    this.avatarUrl,
    required this.points,
    required this.badgeLevel,
    required this.position,
  });

  factory RankingMember.fromJson(Map<String, dynamic> json) {
    return RankingMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      points: json['points'] as int? ?? 0,
      badgeLevel: json['badge_level'] as String,
      position: json['position'] as int? ?? 0,
    );
  }
}

class Achievement {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String category;
  final int? pointsReward;
  final String? icon;

  Achievement({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    this.pointsReward,
    this.icon,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      pointsReward: json['points_reward'] as int?,
      icon: json['icon'] as String?,
    );
  }
}

class PointsHistory {
  final String id;
  final int points;
  final String actionType;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;

  PointsHistory({
    required this.id,
    required this.points,
    required this.actionType,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory PointsHistory.fromJson(Map<String, dynamic> json) {
    return PointsHistory(
      id: json['id'] as String,
      points: json['points'] as int? ?? 0,
      actionType: json['action_type'] as String,
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GamificationService {
  static Future<List<RankingMember>> getRanking(String fanClubId, {int limit = 20}) async {
    try {
      final response = await SupabaseService.client
          .from('fan_club_members')
          .select('''
            id,
            user_id,
            points,
            badge_level,
            profiles!inner (
              full_name,
              nickname,
              avatar_url
            )
          ''')
          .eq('fan_club_id', fanClubId)
          .eq('status', 'active')
          .order('points', ascending: false)
          .limit(limit);

      final List<dynamic> data = (response as List? ?? []);
      List<RankingMember> ranking = [];

      for (int i = 0; i < data.length; i++) {
        final item = data[i] as Map<String, dynamic>;
        final profile = item['profiles'] as Map<String, dynamic>?;

        ranking.add(RankingMember(
          id: item['id'] as String,
          userId: item['user_id'] as String,
          fullName: profile?['full_name'] as String? ?? 'Usuário',
          nickname: profile?['nickname'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
          points: item['points'] as int? ?? 0,
          badgeLevel: item['badge_level'] as String,
          position: i + 1,
        ));
      }

      return ranking;
    } catch (e) {
      print('Erro ao buscar ranking: $e');
      return [];
    }
  }

  static Future<List<Achievement>> getMemberAchievements(String memberId) async {
    try {
      final response = await SupabaseService.client
          .from('member_achievements')
          .select('''
            id,
            achieved_at,
            achievements (
              id,
              code,
              name,
              description,
              category,
              points_reward,
              icon
            )
          ''')
          .eq('member_id', memberId)
          .order('achieved_at', ascending: false);

      return ((response as List? ?? []) as List)
          .map((item) {
            final itemData = item as Map<String, dynamic>;
            final achievementData = itemData['achievements'] as Map<String, dynamic>?;
            if (achievementData == null) return null;
            return Achievement.fromJson(achievementData);
          })
          .whereType<Achievement>()
          .toList();
    } catch (e) {
      print('Erro ao buscar conquistas: $e');
      return [];
    }
  }

  static Future<List<PointsHistory>> getPointsHistory(String memberId, {int limit = 50}) async {
    try {
      final response = await SupabaseService.client
          .from('points_history')
          .select()
          .eq('member_id', memberId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List? ?? [])
          .map((item) => PointsHistory.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('Erro ao buscar histórico de pontos: $e');
      return [];
    }
  }
}

