import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final bool isAdmin;
  final VoidCallback? onRegister;
  final VoidCallback? onCancelRegistration;
  final VoidCallback? onViewDetails;
  final bool loading;
  /// Sobrescreve event.userRegistered (ex.: após inscrever/cancelar sem recarregar a tela).
  final bool? overrideUserRegistered;

  const EventCard({
    super.key,
    required this.event,
    this.isAdmin = false,
    this.onRegister,
    this.onCancelRegistration,
    this.onViewDetails,
    this.loading = false,
    this.overrideUserRegistered,
  });

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM • HH:mm', 'pt_BR').format(date);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day));
    if (diff.inDays == 0) {
      return 'Hoje • ${DateFormat('HH:mm').format(date)}';
    }
    if (diff.inDays == 1) return 'Amanhã • ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays > 1 && diff.inDays <= 7) {
      return 'Em ${diff.inDays} dias • ${DateFormat('dd/MM HH:mm').format(date)}';
    }
    return _formatDate(date);
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagem do evento
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: event.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: AppColors.background,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildImagePlaceholder(160),
                    ),
                  ),
                  if (isPast)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                      ),
                    ),
                  // Chip tipo no canto
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                  ),
                ],
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getEventTypeIcon(event.eventType),
                    size: 44,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Data (destaque: relativa se futuro)
                  _buildInfoRow(
                    Icons.calendar_today_rounded,
                    isPast ? _formatDate(event.eventDate) : _formatRelativeDate(event.eventDate),
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on_rounded, event.location!),
                  ],
                  if (event.maxParticipants != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
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
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'R\$ ${event.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Ações / status
                  if (canRegister)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : onRegister,
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
                                height: 20,
                                width: 20,
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Você está inscrito',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (canCancel)
                            TextButton(
                              onPressed: onCancelRegistration,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Cancelar'),
                            ),
                        ],
                      ),
                    ),
                  ]
                  else if (isFull)
                    _buildStatusChip(
                      Icons.person_off_rounded,
                      'Evento lotado',
                      AppColors.warning,
                    )
                  else if (isPast)
                    _buildStatusChip(
                      Icons.event_busy_rounded,
                      'Evento encerrado',
                      AppColors.textSecondary,
                    )
                  else if (isDeadlinePassed)
                    _buildStatusChip(
                      Icons.schedule_rounded,
                      'Inscrições encerradas',
                      AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(double height) {
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
