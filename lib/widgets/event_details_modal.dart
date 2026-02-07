import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';

/// Modal de detalhes do evento (adaptado da versão web para mobile).
/// Exibe título, data, local, descrição, preço, inscritos e ações (inscrever/cancelar).
class EventDetailsModal extends StatelessWidget {
  final Event event;
  final bool isAdmin;
  /// Pode ser async; o modal fecha após conclusão.
  final Future<void> Function()? onRegister;
  final Future<void> Function()? onCancelRegistration;
  final VoidCallback onClose;
  final bool loading;
  final bool? overrideUserRegistered;

  const EventDetailsModal({
    super.key,
    required this.event,
    required this.onClose,
    this.isAdmin = false,
    this.onRegister,
    this.onCancelRegistration,
    this.loading = false,
    this.overrideUserRegistered,
  });

  static Future<void> show(
    BuildContext context, {
    required Event event,
    VoidCallback? onClose,
    bool isAdmin = false,
    Future<void> Function()? onRegister,
    Future<void> Function()? onCancelRegistration,
    bool loading = false,
    bool? overrideUserRegistered,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailsModal(
        event: event,
        onClose: () {
          Navigator.of(context).pop();
          onClose?.call();
        },
        isAdmin: isAdmin,
        onRegister: onRegister,
        onCancelRegistration: onCancelRegistration,
        loading: loading,
        overrideUserRegistered: overrideUserRegistered,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'pt_BR').format(date);
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'game':
        return Icons.sports_soccer_rounded;
      case 'travel':
        return Icons.directions_bus_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      case 'party':
        return Icons.celebration_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  String _getEventTypeLabel(String eventType) {
    switch (eventType) {
      case 'game':
        return 'Jogo';
      case 'travel':
        return 'Viagem';
      case 'meeting':
        return 'Reunião';
      case 'party':
        return 'Festa';
      default:
        return 'Evento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRegistered = overrideUserRegistered ?? event.userRegistered;
    final isPast = event.eventDate.isBefore(DateTime.now());
    final isDeadlinePassed = event.registrationDeadline != null &&
        event.registrationDeadline!.isBefore(DateTime.now());
    final isFull = event.maxParticipants != null &&
        event.registrationsCount >= event.maxParticipants!;
    final canRegister = !isPast && !isDeadlinePassed && !isFull && !userRegistered;
    final canCancel = userRegistered &&
        event.userRegistrationStatus != 'checked_in' &&
        !isPast;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alça de arraste
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [
                    // Imagem
                    if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: CachedNetworkImage(
                            imageUrl: event.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.background,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _placeholder(180),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.primary.withOpacity(0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _getEventTypeIcon(event.eventType),
                          size: 48,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                      ),
                    if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                      const SizedBox(height: 20),

                    // Tipo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getEventTypeIcon(event.eventType),
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getEventTypeLabel(event.eventType),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Título
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data e hora
                    _infoRow(
                      Icons.calendar_today_rounded,
                      _formatDate(event.eventDate),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.access_time_rounded,
                      _formatTime(event.eventDate),
                    ),
                    if (event.endDate != null) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.flag_rounded,
                        'Até ${_formatTime(event.endDate!)}',
                      ),
                    ],

                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(Icons.location_on_rounded, event.location!),
                    ],

                    if (event.maxParticipants != null) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.people_rounded,
                        '${event.registrationsCount}/${event.maxParticipants} inscritos',
                      ),
                    ],

                    if (event.isPaid) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'R\$ ${event.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Descrição
                    if (event.description != null &&
                        event.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Descrição',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Ações / status
                    if (canRegister)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading || onRegister == null
                              ? null
                              : () async {
                                  await (onRegister?.call() ?? Future<void>.value());
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textLight,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Inscrever-se'),
                        ),
                      )
                    else if (userRegistered) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Você está inscrito',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (canCancel)
                              TextButton(
                                onPressed: onCancelRegistration == null
                                    ? null
                                    : () async {
                                        await (onCancelRegistration?.call() ?? Future<void>.value());
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: const Text('Cancelar inscrição'),
                              ),
                          ],
                        ),
                      ),
                    ]
                    else if (isFull)
                      _statusChip(
                        Icons.person_off_rounded,
                        'Evento lotado',
                        AppColors.warning,
                      )
                    else if (isPast)
                      _statusChip(
                        Icons.event_busy_rounded,
                        'Evento encerrado',
                        AppColors.textSecondary,
                      )
                    else if (isDeadlinePassed)
                      _statusChip(
                        Icons.schedule_rounded,
                        'Inscrições encerradas',
                        AppColors.textSecondary,
                      ),

                    const SizedBox(height: 16),

                    // Botão fechar
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onClose();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder(double height) {
    return Container(
      height: height,
      color: AppColors.background,
      child: Icon(
        Icons.event_rounded,
        size: 48,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
