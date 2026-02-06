import '../services/supabase_service.dart';
import '../models/supabase_models.dart';

/// Serviço de notificações do usuário (exibidas após o login).
class NotificationService {
  /// Busca todas as notificações do usuário, mais recentes primeiro.
  static Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      final List<dynamic> data = (response as List? ?? []);
      return data
          .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('NotificationService: erro ao buscar notificações ($e). Tabela notifications pode não existir.');
      return [];
    }
  }

  /// Conta notificações não lidas (schema WEB App: is_read).
  static Future<int> getUnreadCount(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final List<dynamic> data = (response as List? ?? []);
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  /// Marca uma notificação como lida (schema WEB App: is_read).
  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Erro ao marcar notificação como lida: $e');
    }
  }

  /// Marca todas as notificações do usuário como lidas.
  static Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Erro ao marcar todas como lidas: $e');
    }
  }
}
