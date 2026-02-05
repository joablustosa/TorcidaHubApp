// Modelos para o Supabase - Torcida Hub

class Profile {
  final String id;
  final String? fullName;
  final String? nickname;
  final String? avatarUrl;
  final String? email;
  final bool? emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.nickname,
    this.avatarUrl,
    this.email,
    this.emailVerified,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'email': email,
      'email_verified': emailVerified,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class FanClub {
  final String id;
  final String name;
  final String teamName;
  final String? city;
  final String? state;
  final String? logoUrl;
  final String? coverUrl;
  final String? description;
  final int? foundedYear;
  final bool isVerified;
  final bool? isOfficial;
  final bool? isPublic;
  final String? joinMode;
  final String? createdBy;
  final String? sportType;
  final String? clubType;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  FanClub({
    required this.id,
    required this.name,
    required this.teamName,
    this.city,
    this.state,
    this.logoUrl,
    this.coverUrl,
    this.description,
    this.foundedYear,
    this.isVerified = false,
    this.isOfficial,
    this.isPublic,
    this.joinMode,
    this.createdBy,
    this.sportType,
    this.clubType,
    this.createdAt,
    this.deletedAt,
  });

  factory FanClub.fromJson(Map<String, dynamic> json) {
    return FanClub(
      id: json['id'] as String,
      name: json['name'] as String,
      teamName: json['team_name'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      foundedYear: json['founded_year'] as int?,
      isVerified: json['is_verified'] as bool? ?? false,
      isOfficial: json['is_official'] as bool?,
      isPublic: json['is_public'] as bool?,
      joinMode: json['join_mode'] as String?,
      createdBy: json['created_by'] as String?,
      sportType: json['sport_type'] as String?,
      clubType: json['club_type'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'team_name': teamName,
      'city': city,
      'state': state,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'description': description,
      'founded_year': foundedYear,
      'is_verified': isVerified,
      'is_official': isOfficial,
      'is_public': isPublic,
      'join_mode': joinMode,
      'created_by': createdBy,
      'sport_type': sportType,
      'club_type': clubType,
      'created_at': createdAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}

class FanClubMember {
  final String id;
  final String fanClubId;
  final String userId;
  final String position;
  final String status;
  final String badgeLevel;
  final String registrationNumber;
  final int points;
  final DateTime? joinedAt;
  final DateTime? createdAt;

  FanClubMember({
    required this.id,
    required this.fanClubId,
    required this.userId,
    required this.position,
    required this.status,
    required this.badgeLevel,
    required this.registrationNumber,
    this.points = 0,
    this.joinedAt,
    this.createdAt,
  });

  factory FanClubMember.fromJson(Map<String, dynamic> json) {
    return FanClubMember(
      id: json['id'] as String,
      fanClubId: json['fan_club_id'] as String,
      userId: json['user_id'] as String,
      position: json['position'] as String,
      status: json['status'] as String,
      badgeLevel: json['badge_level'] as String,
      registrationNumber: json['registration_number'] as String,
      points: json['points'] as int? ?? 0,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fan_club_id': fanClubId,
      'user_id': userId,
      'position': position,
      'status': status,
      'badge_level': badgeLevel,
      'registration_number': registrationNumber,
      'points': points,
      'joined_at': joinedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class Post {
  final String id;
  final String fanClubId;
  final String userId;
  final String? content;
  final String? imageUrl;
  final String? videoUrl;
  final List<String>? imageUrls;
  final bool isPinned;
  final bool allowComments;
  final int likesCount;
  final int commentsCount;
  final bool userLiked;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Profile? author;

  Post({
    required this.id,
    required this.fanClubId,
    required this.userId,
    this.content,
    this.imageUrl,
    this.videoUrl,
    this.imageUrls,
    this.isPinned = false,
    this.allowComments = true,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.userLiked = false,
    required this.createdAt,
    this.updatedAt,
    this.author,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    Profile? authorProfile;
    if (json['profiles'] != null) {
      authorProfile = Profile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return Post(
      id: json['id'] as String,
      fanClubId: json['fan_club_id'] as String,
      userId: json['author_id'] as String? ?? json['user_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'] as List)
          : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      allowComments: json['allow_comments'] as bool? ?? true,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      author: authorProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fan_club_id': fanClubId,
      'author_id': userId,
      'content': content,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'image_urls': imageUrls,
      'is_pinned': isPinned,
      'allow_comments': allowComments,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Event {
  final String id;
  final String fanClubId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? endDate;
  final String? location;
  final String? imageUrl;
  final String eventType;
  final bool isPublic;
  final bool isPaid;
  final double price;
  final int? maxParticipants;
  final DateTime? registrationDeadline;
  final String status;
  final int registrationsCount;
  final bool userRegistered;
  final String? userRegistrationStatus;
  final String? userPaymentStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Event({
    required this.id,
    required this.fanClubId,
    required this.title,
    this.description,
    required this.eventDate,
    this.endDate,
    this.location,
    this.imageUrl,
    required this.eventType,
    this.isPublic = true,
    this.isPaid = false,
    this.price = 0.0,
    this.maxParticipants,
    this.registrationDeadline,
    this.status = 'active',
    this.registrationsCount = 0,
    this.userRegistered = false,
    this.userRegistrationStatus,
    this.userPaymentStatus,
    required this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      fanClubId: json['fan_club_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      location: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
      eventType: json['event_type'] as String,
      isPublic: json['is_public'] as bool? ?? true,
      isPaid: json['is_paid'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxParticipants: json['max_participants'] as int?,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
      registrationsCount: json['registrations_count'] as int? ?? 0,
      userRegistered: json['user_registered'] as bool? ?? false,
      userRegistrationStatus: json['user_registration_status'] as String?,
      userPaymentStatus: json['user_payment_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fan_club_id': fanClubId,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'location': location,
      'image_url': imageUrl,
      'event_type': eventType,
      'is_public': isPublic,
      'is_paid': isPaid,
      'price': price,
      'max_participants': maxParticipants,
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Plano de assinatura da torcida (pago por membros).
class SubscriptionPlan {
  final String id;
  final String? fanClubId;
  final String name;
  final String? description;
  final double price;
  final String interval; // 'monthly' | 'yearly'
  final List<String>? features;
  final bool isActive;
  final DateTime? createdAt;

  SubscriptionPlan({
    required this.id,
    this.fanClubId,
    required this.name,
    this.description,
    required this.price,
    this.interval = 'monthly',
    this.features,
    this.isActive = true,
    this.createdAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    List<String>? featuresList;
    if (json['features'] != null) {
      if (json['features'] is List) {
        featuresList = (json['features'] as List).map((e) => e.toString()).toList();
      }
    }
    return SubscriptionPlan(
      id: json['id'] as String,
      fanClubId: json['fan_club_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      interval: json['interval'] as String? ?? 'monthly',
      features: featuresList,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  String get intervalLabel => interval == 'yearly' ? 'ano' : 'mês';
}
