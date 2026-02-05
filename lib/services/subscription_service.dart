import '../services/supabase_service.dart';
import '../models/supabase_models.dart';

/// Serviço de planos de assinatura da torcida.
/// Qualquer membro (incluindo membro comum) pode ver planos e assinar.
class SubscriptionService {
  /// Busca planos disponíveis para a torcida.
  /// Se a tabela subscription_plans existir no Supabase, usa ela; senão retorna planos padrão.
  static Future<List<SubscriptionPlan>> getPlansForFanClub(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('subscription_plans')
          .select()
          .eq('fan_club_id', fanClubId)
          .eq('is_active', true)
          .order('price', ascending: true);

      final List<dynamic> data = (response as List? ?? []);
      if (data.isNotEmpty) {
        return data
            .map((item) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      print('SubscriptionService: tabela subscription_plans não encontrada ou erro: $e');
    }

    // Planos padrão quando a tabela não existe ou está vazia (qualquer membro vê)
    return _getDefaultPlans(fanClubId);
  }

  static List<SubscriptionPlan> _getDefaultPlans(String fanClubId) {
    return [
      SubscriptionPlan(
        id: 'default_basico',
        fanClubId: fanClubId,
        name: 'Plano Básico',
        description: 'Acesso às atividades da torcida e eventos.',
        price: 9.90,
        interval: 'monthly',
        features: ['Acesso ao feed', 'Participação em eventos', 'Ranking'],
        isActive: true,
      ),
      SubscriptionPlan(
        id: 'default_premium',
        fanClubId: fanClubId,
        name: 'Plano Premium',
        description: 'Tudo do Básico + benefícios exclusivos.',
        price: 19.90,
        interval: 'monthly',
        features: ['Tudo do Básico', 'Camisa oficial', 'Desconto em eventos', 'Badge exclusivo'],
        isActive: true,
      ),
      SubscriptionPlan(
        id: 'default_anual',
        fanClubId: fanClubId,
        name: 'Plano Anual',
        description: '12 meses com desconto.',
        price: 99.90,
        interval: 'yearly',
        features: ['Tudo do Premium', '2 meses grátis', 'Kit torcedor'],
        isActive: true,
      ),
    ];
  }

  /// Assina um plano: cria registro de assinatura e, se pago, retorna dados do PIX.
  /// Qualquer membro pode chamar (não exige permissão de admin).
  static Future<Map<String, dynamic>?> subscribeToPlan({
    required String planId,
    required String userId,
    required String fanClubId,
    required double price,
  }) async {
    try {
      // Inserir assinatura (tabela member_subscriptions, se existir no Supabase)
      try {
        await SupabaseService.client.from('member_subscriptions').insert({
          'user_id': userId,
          'plan_id': planId,
          'fan_club_id': fanClubId,
          'status': price > 0 ? 'pending_payment' : 'active',
          'started_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('SubscriptionService: member_subscriptions não existe ou erro: $e');
        // Continuar para tentar criar PIX mesmo assim
      }

      if (price <= 0) return null;

      // Criar pagamento PIX (RPC pode ser create_pix_payment com tipo subscription ou create_subscription_pix_payment)
      try {
        final paymentResponse = await SupabaseService.client.rpc(
          'create_subscription_pix_payment',
          params: {
            'p_plan_id': planId,
            'p_user_id': userId,
            'p_fan_club_id': fanClubId,
            'p_amount': price,
          },
        );
        if (paymentResponse != null) {
          return Map<String, dynamic>.from(paymentResponse);
        }
      } catch (rpcError) {
        print('SubscriptionService: create_subscription_pix_payment não existe: $rpcError');
        // Fallback: tentar RPC genérico de evento com descrição de plano
        try {
          final paymentResponse = await SupabaseService.client.rpc(
            'create_pix_payment',
            params: {
              'p_event_id': null,
              'p_user_id': userId,
              'p_amount': price,
              'p_description': 'Assinatura plano',
            },
          );
          if (paymentResponse != null) {
            return Map<String, dynamic>.from(paymentResponse);
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      print('Erro ao assinar plano: $e');
      rethrow;
    }
  }
}
