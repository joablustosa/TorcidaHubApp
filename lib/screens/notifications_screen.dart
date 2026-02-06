import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/notification_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';

/// Tela que exibe todas as notificações do usuário (acessada pelo ícone de sino após o login).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthServiceSupabase();
  Future<List<AppNotification>>? _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    if (_authService.userId == null) return;
    setState(() {
      _notificationsFuture = NotificationService.getNotifications(_authService.userId!);
    });
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    await NotificationService.markAsRead(n.id);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    if (_authService.userId == null) return;
    await NotificationService.markAllAsRead(_authService.userId!);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Notificações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        foregroundColor: AppColors.textLight,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.darkGreen],
            ),
          ),
        ),
        actions: [
          FutureBuilder<int>(
            future: _authService.userId != null
                ? NotificationService.getUnreadCount(_authService.userId!)
                : Future.value(0),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Marcar todas como lidas', style: TextStyle(color: Colors.white70, fontSize: 12)),
              );
            },
          ),
        ],
      ),
      body: _authService.userId == null
          ? const Center(child: Text('Faça login para ver notificações.'))
          : FutureBuilder<List<AppNotification>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Erro ao carregar notificações.', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma notificação',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quando houver novidades, elas aparecerão aqui.',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _loadNotifications(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final n = list[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _markAsRead(n),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Material(
      color: isUnread ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Icon(_iconForType(notification.type), color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (notification.message != null && notification.message!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message!,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(notification.createdAt),
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'event':
        return Icons.event_rounded;
      case 'post':
        return Icons.article_rounded;
      case 'member':
        return Icons.people_rounded;
      case 'payment':
        return Icons.payment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays} dia(s)';
    return '${d.day}/${d.month}/${d.year}';
  }
}
