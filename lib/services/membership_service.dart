import 'supabase_service.dart';

/// Dados da assinatura do membro (retorno do get_member_subscription).
class MemberSubscription {
  final String? subscriptionId;
  final String? planId;
  final String? planName;
  final double? planPrice;
  final String? status;
  final DateTime? expiresAt;
  final DateTime? gracePeriodEnd;
  final bool isInGracePeriod;

  MemberSubscription({
    this.subscriptionId,
    this.planId,
    this.planName,
    this.planPrice,
    this.status,
    this.expiresAt,
    this.gracePeriodEnd,
    this.isInGracePeriod = false,
  });

  bool get isSubscribed =>
      status == 'active' || (status == 'expired' && isInGracePeriod);
}

/// Plano de assinatura da torcida.
class MembershipPlan {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String billingPeriod;
  final List<String> benefits;
  final bool isDefault;
  final bool isActive;

  MembershipPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.billingPeriod,
    this.benefits = const [],
    this.isDefault = false,
    this.isActive = true,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    final benefitsRaw = json['benefits'];
    List<String> benefitsList = [];
    if (benefitsRaw is List) {
      benefitsList =
          benefitsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return MembershipPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      billingPeriod: json['billing_period'] as String? ?? 'monthly',
      benefits: benefitsList,
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Configurações de acesso por assinatura (fan_clubs.membership_access_settings).
class MembershipAccessConfig {
  final bool postsExclusive;
  final bool eventsExclusive;
  final bool storeDiscount;
  final bool rankingExclusive;
  final bool albumsExclusive;
  final int defaultMemberDiscount;

  MembershipAccessConfig({
    this.postsExclusive = true,
    this.eventsExclusive = true,
    this.storeDiscount = true,
    this.rankingExclusive = false,
    this.albumsExclusive = false,
    this.defaultMemberDiscount = 10,
  });
}

/// Serviço de assinatura (membership) da torcida.
class MembershipService {
  /// Busca assinatura do membro via RPC get_member_subscription.
  static Future<MemberSubscription?> getMemberSubscription(String memberId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_member_subscription',
        params: {'_member_id': memberId},
      );

      if (response == null || response is! List || response.isEmpty) {
        return null;
      }

      final sub = response.first as Map<String, dynamic>;
      return MemberSubscription(
        subscriptionId: sub['subscription_id']?.toString(),
        planId: sub['plan_id']?.toString(),
        planName: sub['plan_name'] as String?,
        planPrice: sub['plan_price'] != null
            ? (sub['plan_price'] as num).toDouble()
            : null,
        status: sub['status'] as String?,
        expiresAt: sub['expires_at'] != null
            ? DateTime.parse(sub['expires_at'] as String)
            : null,
        gracePeriodEnd: sub['grace_period_end'] != null
            ? DateTime.parse(sub['grace_period_end'] as String)
            : null,
        isInGracePeriod: sub['is_in_grace_period'] as bool? ?? false,
      );
    } catch (e) {
      print('Erro ao buscar assinatura: $e');
      return null;
    }
  }

  /// Busca planos ativos da torcida (equivale ao curl com select=*&is_active=eq.true&order=price.asc).
  static Future<List<MembershipPlan>> getPlans(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('membership_plans')
          .select('*')
          .eq('fan_club_id', fanClubId)
          .eq('is_active', true)
          .order('price', ascending: true);

      return _parsePlansResponse(response);
    } catch (e) {
      print('Erro ao buscar planos (getPlans): $e');
      return [];
    }
  }

  /// Busca todos os planos (incluindo inativos) para administração.
  static Future<List<MembershipPlan>> getAllPlans(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('membership_plans')
          .select('*')
          .eq('fan_club_id', fanClubId)
          .order('price', ascending: true);

      return _parsePlansResponse(response);
    } catch (e) {
      print('Erro ao buscar planos (getAllPlans): $e');
      return [];
    }
  }

  static List<MembershipPlan> _parsePlansResponse(dynamic response) {
    if (response == null) return [];
    if (response is! List) return [];
    final List<dynamic> data = response;
    final List<MembershipPlan> plans = [];
    for (final item in data) {
      try {
        if (item is Map<String, dynamic>) {
          plans.add(MembershipPlan.fromJson(item));
        } else if (item is Map) {
          plans.add(MembershipPlan.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        print('Erro ao parsear plano: $e - item: $item');
      }
    }
    return plans;
  }

  /// Atualiza requires_membership_fee da torcida.
  static Future<void> updateRequiresMembership(
      String fanClubId, bool value) async {
    await SupabaseService.client
        .from('fan_clubs')
        .update({'requires_membership_fee': value}).eq('id', fanClubId);
  }

  /// Cria ou atualiza plano.
  static Future<void> savePlan({
    required String fanClubId,
    String? planId,
    required String name,
    String? description,
    required double price,
    required String billingPeriod,
    required List<String> benefits,
    required bool isActive,
    required bool isDefault,
  }) async {
    final planData = {
      'fan_club_id': fanClubId,
      'name': name,
      'description': description,
      'price': price,
      'billing_period': billingPeriod,
      'benefits': benefits,
      'is_active': isActive,
      'is_default': isDefault,
    };
    if (planId != null && planId.isNotEmpty) {
      if (isDefault) {
        await _clearDefault(fanClubId);
      }
      await SupabaseService.client
          .from('membership_plans')
          .update(planData)
          .eq('id', planId);
    } else {
      if (isDefault) {
        await _clearDefault(fanClubId);
      }
      await SupabaseService.client
          .from('membership_plans')
          .insert(planData);
    }
  }

  /// Remove default de outros planos antes de definir um novo.
  static Future<void> _clearDefault(String fanClubId) async {
    await SupabaseService.client
        .from('membership_plans')
        .update({'is_default': false}).eq('fan_club_id', fanClubId);
  }

  /// Atualiza status ativo do plano.
  static Future<void> togglePlanActive(String planId, bool isActive) async {
    await SupabaseService.client
        .from('membership_plans')
        .update({'is_active': isActive}).eq('id', planId);
  }

  /// Exclui plano.
  static Future<void> deletePlan(String planId) async {
    await SupabaseService.client
        .from('membership_plans')
        .delete()
        .eq('id', planId);
  }

  /// Salva configurações de acesso e período de carência.
  static Future<void> saveAccessSettings({
    required String fanClubId,
    required bool requiresMembership,
    required MembershipAccessConfig settings,
    int gracePeriodDays = 7,
  }) async {
    await SupabaseService.client.from('fan_clubs').update({
      'requires_membership_fee': requiresMembership,
      'membership_grace_period_days': gracePeriodDays,
      'membership_access_settings': {
        'posts_exclusive': settings.postsExclusive,
        'events_exclusive': settings.eventsExclusive,
        'store_discount': settings.storeDiscount,
        'ranking_exclusive': settings.rankingExclusive,
        'albums_exclusive': settings.albumsExclusive,
        'default_member_discount': settings.defaultMemberDiscount,
      },
    }).eq('id', fanClubId);
  }

  /// Busca período de carência.
  static Future<int> getGracePeriodDays(String fanClubId) async {
    try {
      final r = await SupabaseService.client
          .from('fan_clubs')
          .select('membership_grace_period_days')
          .eq('id', fanClubId)
          .maybeSingle();
      return (r?['membership_grace_period_days'] as num?)?.toInt() ?? 7;
    } catch (_) {
      return 7;
    }
  }

  /// Verifica se a torcida pode receber pagamentos (pix_key ou pagarme_recipient_id).
  static Future<bool> canReceivePayments(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('fan_clubs')
          .select('pix_key, pagarme_recipient_id')
          .eq('id', fanClubId)
          .maybeSingle();

      if (response == null) return false;
      final pixKey = response['pix_key'] as String?;
      final recipientId = response['pagarme_recipient_id'] as String?;
      return (pixKey != null && pixKey.trim().isNotEmpty) ||
          (recipientId != null && recipientId.trim().isNotEmpty);
    } catch (e) {
      print('Erro ao verificar recebedor: $e');
      return false;
    }
  }

  /// Busca configurações de acesso (requires_membership_fee, membership_access_settings).
  static Future<({
    bool requiresMembership,
    MembershipAccessConfig settings,
  })> getAccessSettings(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('fan_clubs')
          .select('requires_membership_fee, membership_access_settings')
          .eq('id', fanClubId)
          .maybeSingle();

      if (response == null) {
        return (requiresMembership: false, settings: MembershipAccessConfig());
      }

      final requires = response['requires_membership_fee'] as bool? ?? false;
      final raw = response['membership_access_settings'] as Map<String, dynamic>?;

      MembershipAccessConfig settings = MembershipAccessConfig();
      if (raw != null) {
        settings = MembershipAccessConfig(
          postsExclusive: raw['posts_exclusive'] as bool? ?? true,
          eventsExclusive: raw['events_exclusive'] as bool? ?? true,
          storeDiscount: raw['store_discount'] as bool? ?? true,
          rankingExclusive: raw['ranking_exclusive'] as bool? ?? false,
          albumsExclusive: raw['albums_exclusive'] as bool? ?? false,
          defaultMemberDiscount:
              (raw['default_member_discount'] as num?)?.toInt() ?? 10,
        );
      }

      return (requiresMembership: requires, settings: settings);
    } catch (e) {
      print('Erro ao buscar access settings: $e');
      return (requiresMembership: false, settings: MembershipAccessConfig());
    }
  }

  /// Cria pagamento de assinatura via edge function create-membership-payment.
  /// Corresponde ao curl: POST /functions/v1/create-membership-payment com body JSON.
  static Future<Map<String, dynamic>?> createMembershipPayment({
    required String fanClubId,
    required String memberId,
    required String planId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    String? customerCpf,
  }) async {
    try {
      final body = <String, dynamic>{
        'fan_club_id': fanClubId,
        'member_id': memberId,
        'plan_id': planId,
        'customer_name': customerName.trim(),
        'customer_email': customerEmail.trim(),
      };
      if (customerPhone != null && customerPhone.trim().isNotEmpty) {
        body['customer_phone'] = customerPhone.trim();
      }
      if (customerCpf != null && customerCpf.trim().isNotEmpty) {
        body['customer_cpf'] = customerCpf.trim();
      }

      final response = await SupabaseService.client.functions.invoke(
        'create-membership-payment',
        body: body,
      );

      if (response.status != 200) {
        final err = response.data;
        final msg = err is Map && err['error'] != null
            ? err['error'].toString()
            : 'Erro ao gerar pagamento (${response.status})';
        throw Exception(msg);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Resposta inválida da API');
      }
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }
}
