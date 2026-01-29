import '../services/supabase_service.dart';
import '../models/supabase_models.dart';

class EventService {
  static Future<List<Event>> getEvents({
    required String fanClubId,
    String? userId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('events')
          .select()
          .eq('fan_club_id', fanClubId)
          .order('event_date', ascending: true);

      final List<dynamic> data = (response as List? ?? []);
      List<Event> events = data
          .map((item) => Event.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      // Buscar registros se userId fornecido
      if (userId != null && events.isNotEmpty) {
        final eventIds = events.map((e) => e.id).toList();
        // Buscar registros para cada evento
        final registrationsResponse = await SupabaseService.client
            .from('event_registrations')
            .select('event_id, user_id, status, payment_status');

        final registrations = (registrationsResponse as List? ?? []);
        if (registrations.isNotEmpty) {
          final registrationCounts = <String, int>{};
          final userRegistrations = <String, Map<String, String>>{};

          for (var reg in registrations) {
            final regData = reg as Map<String, dynamic>;
            final eventId = regData['event_id'] as String;
            final regUserId = regData['user_id'] as String;
            final regStatus = regData['status'] as String;

            // Filtrar apenas registros não cancelados e que sejam dos eventos buscados
            if (regStatus != 'cancelled' && eventIds.contains(eventId)) {
              // Contar registros
              registrationCounts[eventId] = (registrationCounts[eventId] ?? 0) + 1;

              // Verificar registro do usuário
              if (regUserId == userId) {
                userRegistrations[eventId] = {
                  'status': regStatus,
                  'payment_status': regData['payment_status'] as String? ?? '',
                };
              }
            }
          }

          // Enriquecer eventos com dados de registro
          events = events.map((event) {
            final userReg = userRegistrations[event.id];
            return Event(
              id: event.id,
              fanClubId: event.fanClubId,
              title: event.title,
              description: event.description,
              eventDate: event.eventDate,
              endDate: event.endDate,
              location: event.location,
              imageUrl: event.imageUrl,
              eventType: event.eventType,
              isPublic: event.isPublic,
              isPaid: event.isPaid,
              price: event.price,
              maxParticipants: event.maxParticipants,
              registrationDeadline: event.registrationDeadline,
              status: event.status,
              registrationsCount: registrationCounts[event.id] ?? 0,
              userRegistered: userReg != null,
              userRegistrationStatus: userReg?['status'],
              userPaymentStatus: userReg?['payment_status'],
              createdAt: event.createdAt,
              updatedAt: event.updatedAt,
            );
          }).toList();
        }
      }

      return events;
    } catch (e) {
      print('Erro ao buscar eventos: $e');
      return [];
    }
  }

  static Future<Event> createEvent({
    required String fanClubId,
    required String userId,
    required String title,
    String? description,
    required DateTime eventDate,
    DateTime? endDate,
    String? location,
    String? imageUrl,
    required String eventType,
    bool isPublic = true,
    bool isPaid = false,
    double price = 0.0,
    int? maxParticipants,
    DateTime? registrationDeadline,
  }) async {
    try {
      final eventData = {
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
        'status': 'active',
      };

      final response = await SupabaseService.client
          .from('events')
          .insert(eventData)
          .select()
          .single();

      return Event.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao criar evento: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> registerForEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      // Buscar informações do evento
      final eventResponse = await SupabaseService.client
          .from('events')
          .select()
          .eq('id', eventId)
          .single();

      if (eventResponse == null) {
        throw Exception('Evento não encontrado');
      }

      final eventData = Map<String, dynamic>.from(eventResponse);
      final isPaid = eventData['is_paid'] as bool? ?? false;
      final price = (eventData['price'] as num?)?.toDouble() ?? 0.0;

      // Criar registro
      final registrationResponse = await SupabaseService.client
          .from('event_registrations')
          .insert({
        'event_id': eventId,
        'user_id': userId,
        'status': isPaid ? 'pending_payment' : 'confirmed',
        'payment_status': isPaid ? 'pending' : 'paid',
      }).select().single();

      if (registrationResponse == null) {
        throw Exception('Erro ao criar registro');
      }

      // Se for evento pago, criar pagamento PIX
      if (isPaid && price > 0) {
        try {
          // Chamar função RPC para criar pagamento PIX
          final paymentResponse = await SupabaseService.client.rpc(
            'create_pix_payment',
            params: {
              'p_event_id': eventId,
              'p_user_id': userId,
              'p_amount': price,
            },
          );

          if (paymentResponse != null) {
            return Map<String, dynamic>.from(paymentResponse);
          }
        } catch (e) {
          print('Erro ao criar pagamento PIX: $e');
          // Continuar mesmo se falhar (pode ser que a função RPC não exista ainda)
        }
      }

      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') || msg.toLowerCase().contains('duplicate key')) {
        throw Exception('ALREADY_REGISTERED');
      }
      print('Erro ao se inscrever no evento: $e');
      rethrow;
    }
  }

  static Future<void> cancelRegistration({
    required String eventId,
    required String userId,
  }) async {
    try {
      await SupabaseService.client
          .from('event_registrations')
          .update({'status': 'cancelled'})
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erro ao cancelar inscrição: $e');
      rethrow;
    }
  }
}

