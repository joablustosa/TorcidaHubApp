import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../services/album_service.dart';
import '../services/event_service.dart';
import '../screens/album_detail_screen.dart';

/// Modal de detalhes do evento (adaptado da versão web para mobile).
/// Exibe título, data, local, descrição, preço, inscritos, álbuns, participantes, check-ins, caravanas e ações.
class EventDetailsModal extends StatefulWidget {
  final Event event;
  final bool isAdmin;
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

  @override
  State<EventDetailsModal> createState() => _EventDetailsModalState();
}

class _EventDetailsModalState extends State<EventDetailsModal> {
  List<Album> _albums = [];
  List<EventRegistration> _registrations = [];
  List<Caravan> _caravans = [];
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final eventId = widget.event.id;
    try {
      final results = await Future.wait([
        AlbumService.getAlbumsForEvent(eventId),
        EventService.getEventRegistrations(eventId),
        EventService.getCaravans(eventId),
      ]);
      if (mounted) {
        setState(() {
          _albums = results[0] as List<Album>;
          _registrations = results[1] as List<EventRegistration>;
          _caravans = results[2] as List<Caravan>;
          _loadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Event get event => widget.event;

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

                    // Álbuns do evento
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.photo_library_rounded, 'Álbuns', _albums.length),
                    if (_loadingDetails)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        ),
                      )
                    else if (_albums.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nenhum álbum associado',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...List.generate(_albums.length, (i) {
                        final album = _albums[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(
                                      album: album,
                                      canUploadPhotos: false,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    if (album.coverPhotoUrl != null && album.coverPhotoUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: album.coverPhotoUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _albumPlaceholder(),
                                        ),
                                      )
                                    else
                                      _albumPlaceholder(),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(album.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          Text('${album.photoCount} fotos', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    // Participantes
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.people_rounded, 'Participantes', _registrations.length),
                    if (!_loadingDetails && _registrations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhum participante inscrito', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      )
                    else if (!_loadingDetails)
                      ...List.generate(_registrations.length, (i) {
                        final r = _registrations[i];
                        return _participantTile(r);
                      }),

                    // Check-ins
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.check_circle_rounded, 'Check-ins', _registrations.where((r) => r.status == 'checked_in').length),
                    if (!_loadingDetails && _registrations.where((r) => r.status == 'checked_in').isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhum check-in realizado', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      )
                    else if (!_loadingDetails)
                      ..._registrations.where((r) => r.status == 'checked_in').map(_checkInTile).toList(),

                    // Caravanas
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.directions_bus_rounded, 'Caravanas', _caravans.length),
                    if (!_loadingDetails && _caravans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhuma caravana', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      )
                    else if (!_loadingDetails)
                      ...List.generate(_caravans.length, (i) {
                        final c = _caravans[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(c.departureLocation, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                ]),
                                Row(children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('dd/MM HH:mm').format(c.departureTime), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(width: 12),
                                  Text('${c.maxSeats} vagas', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  if (c.pricePerSeat > 0) Text(' • R\$ ${c.pricePerSeat.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                ]),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Ações / status
                    if (canRegister)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.loading || widget.onRegister == null
                              ? null
                              : () async {
                                  await (widget.onRegister?.call() ?? Future<void>.value());
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
                          child: widget.loading
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
                                onPressed: widget.onCancelRegistration == null
                                    ? null
                                    : () async {
                                        await (widget.onCancelRegistration?.call() ?? Future<void>.value());
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

                    // Botão fechar (apenas onClose para evitar duplo pop)
                    OutlinedButton(
                      onPressed: widget.onClose,
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

  Widget _sectionTitle(IconData icon, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.photo_library_rounded, size: 24, color: AppColors.textSecondary),
    );
  }

  Widget _participantTile(EventRegistration r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(r.avatarUrl!)
                  : null,
              child: r.avatarUrl == null || r.avatarUrl!.isEmpty
                  ? Text(
                      (r.fullName.isNotEmpty ? r.fullName[0] : '?').toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: [
                      _miniChip(r.paymentStatus == 'paid' ? 'Pago' : 'Pendente', r.paymentStatus == 'paid' ? AppColors.success : AppColors.textSecondary),
                      if (r.status == 'checked_in') ...[
                        const SizedBox(width: 6),
                        _miniChip('Check-in ✓', AppColors.success),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInTile(EventRegistration r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: AppColors.success, width: 4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(r.avatarUrl!)
                  : null,
              child: r.avatarUrl == null || r.avatarUrl!.isEmpty
                  ? Text(
                      (r.fullName.isNotEmpty ? r.fullName[0] : '?').toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (r.checkInAt != null)
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(r.checkInAt!)} às ${DateFormat('HH:mm').format(r.checkInAt!)}${r.checkInByName != null ? ' • por ${r.checkInByName}' : ''}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            _miniChip('Presente', AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
