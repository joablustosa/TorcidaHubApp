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

  /// Participantes do evento (inscrições com perfil do usuário).
  static Future<List<EventRegistration>> getEventRegistrations(
      String eventId) async {
    try {
      final response = await SupabaseService.client
          .from('event_registrations')
          .select('id, user_id, status, payment_status, check_in_at, check_in_by')
          .eq('event_id', eventId)
          .neq('status', 'cancelled');

      final List<dynamic> regs = (response as List? ?? []);
      if (regs.isEmpty) return [];

      final userIds = <String>{};
      for (var r in regs) {
        final m = r as Map<String, dynamic>;
        userIds.add(m['user_id'] as String);
        final checkInBy = m['check_in_by'];
        if (checkInBy != null) userIds.add(checkInBy as String);
      }

      final profilesRes = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', userIds.toList());

      final profileMap = <String, Map<String, dynamic>>{};
      for (var p in (profilesRes as List? ?? [])) {
        final m = Map<String, dynamic>.from(p as Map);
        profileMap[m['id'] as String] = m;
      }

      return regs.map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final uid = m['user_id'] as String;
        final profile = profileMap[uid] ?? {'id': uid, 'full_name': 'Usuário', 'avatar_url': null};
        return EventRegistration(
          id: m['id'] as String,
          userId: uid,
          status: m['status'] as String? ?? '',
          paymentStatus: m['payment_status'] as String? ?? '',
          checkInAt: m['check_in_at'] != null
              ? DateTime.parse(m['check_in_at'] as String)
              : null,
          checkInBy: m['check_in_by'] as String?,
          fullName: profile['full_name'] as String? ?? 'Usuário',
          avatarUrl: profile['avatar_url'] as String?,
          checkInByName: profileMap[m['check_in_by'] as String?]?['full_name'] as String?,
        );
      }).toList();
    } catch (e) {
      print('Erro ao buscar participantes: $e');
      return [];
    }
  }

  /// Caravanas do evento.
  static Future<List<Caravan>> getCaravans(String eventId) async {
    try {
      final response = await SupabaseService.client
          .from('caravans')
          .select()
          .eq('event_id', eventId)
          .neq('status', 'cancelled');

      final List<dynamic> data = (response as List? ?? []);
      return data
          .map((item) => Caravan.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('Erro ao buscar caravanas: $e');
      return [];
    }
  }
}

/// Inscrição no evento com dados do usuário (para o modal de detalhes).
class EventRegistration {
  final String id;
  final String userId;
  final String status;
  final String paymentStatus;
  final DateTime? checkInAt;
  final String? checkInBy;
  final String fullName;
  final String? avatarUrl;
  final String? checkInByName;

  EventRegistration({
    required this.id,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    this.checkInAt,
    this.checkInBy,
    required this.fullName,
    this.avatarUrl,
    this.checkInByName,
  });
}

/// Caravana (viagem associada ao evento).
class Caravan {
  final String id;
  final String eventId;
  final String name;
  final String departureLocation;
  final DateTime departureTime;
  final int maxSeats;
  final double pricePerSeat;
  final String? vehicleType;
  final String? status;

  Caravan({
    required this.id,
    required this.eventId,
    required this.name,
    required this.departureLocation,
    required this.departureTime,
    required this.maxSeats,
    this.pricePerSeat = 0,
    this.vehicleType,
    this.status,
  });

  factory Caravan.fromJson(Map<String, dynamic> json) {
    return Caravan(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      departureLocation: json['departure_location'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      maxSeats: json['max_seats'] as int? ?? 0,
      pricePerSeat: (json['price_per_seat'] as num?)?.toDouble() ?? 0,
      vehicleType: json['vehicle_type'] as String?,
      status: json['status'] as String?,
    );
  }
}

