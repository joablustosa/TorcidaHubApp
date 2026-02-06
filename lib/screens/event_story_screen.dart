import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../services/viewed_stories_service.dart';

/// Argumentos para abrir a tela de "stories" de eventos de uma torcida.
class EventStoryScreenArgs {
  final String fanClubId;
  final String fanClubName;
  final String? logoUrl;
  final List<Event> events;

  const EventStoryScreenArgs({
    required this.fanClubId,
    required this.fanClubName,
    this.logoUrl,
    required this.events,
  });
}

/// Tela estilo story: um evento por slide; swipe após o último evento da torcida vai para a próxima torcida; swipe após o último de todas fecha.
/// Recebe lista de torcidas (cada uma com sua lista de eventos).
class EventStoryScreen extends StatefulWidget {
  /// Uma torcida (para compatibilidade: converte em lista de um item).
  final EventStoryScreenArgs? args;

  /// Várias torcidas: eventos em sequência; ao passar do último de uma torcida, vai para a próxima; ao passar do último de todas, fecha.
  final List<EventStoryScreenArgs>? argsList;

  EventStoryScreen({super.key, this.args, this.argsList});

  List<EventStoryScreenArgs> get _effectiveList {
    if (argsList != null && argsList!.isNotEmpty) return argsList!;
    if (args != null) return [args!];
    return [];
  }

  @override
  State<EventStoryScreen> createState() => _EventStoryScreenState();
}

class _EventStoryScreenState extends State<EventStoryScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Set<String> _viewedFanClubIds = {};
  late List<({EventStoryScreenArgs args, Event event})> _flattened;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final list = widget._effectiveList;
    _flattened = [];
    for (final a in list) {
      for (final e in a.events) {
        _flattened.add((args: a, event: e));
      }
    }
  }

  @override
  void dispose() {
    if (_viewedFanClubIds.isNotEmpty) {
      ViewedStoriesService.markViewed(_viewedFanClubIds);
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index < _flattened.length) {
      _viewedFanClubIds.add(_flattened[index].args.fanClubId);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR').format(date);
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
    final list = widget._effectiveList;
    final hasAnyEvents = _flattened.isNotEmpty;

    if (!hasAnyEvents) {
      final name = list.isNotEmpty ? list.first.fanClubName : 'Torcida';
      return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Text(
            'Nenhum evento próximo',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final totalPages = _flattened.length + 1;
    final currentArgs = _currentIndex < _flattened.length
        ? _flattened[_currentIndex].args
        : _flattened.last.args;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index == _flattened.length) {
                return _CloseStoryPage(
                  onClose: () => Navigator.of(context).pop(),
                );
              }
              final item = _flattened[index];
              return _StoryEventPage(
                event: item.event,
                args: item.args,
                formatDate: _formatDate,
                getEventTypeLabel: _getEventTypeLabel,
                onTapOpenTorcida: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(
                    '/minha-torcida/${item.args.fanClubId}',
                    arguments: {'tabIndex': 1},
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: List.generate(_flattened.length, (i) {
                      final filled = i < _currentIndex || _currentIndex >= _flattened.length;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: filled
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (currentArgs.logoUrl != null && currentArgs.logoUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: currentArgs.logoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.shield,
                              color: Colors.white.withOpacity(0.8),
                              size: 40,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.shield,
                          color: Colors.white.withOpacity(0.8),
                          size: 40,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentArgs.fanClubName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Página final: ao ser exibida (swipe para a direita após o último story), fecha a tela.
class _CloseStoryPage extends StatefulWidget {
  final VoidCallback onClose;

  const _CloseStoryPage({required this.onClose});

  @override
  State<_CloseStoryPage> createState() => _CloseStoryPageState();
}

class _CloseStoryPageState extends State<_CloseStoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Fim dos stories',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ),
    );
  }
}

class _StoryEventPage extends StatelessWidget {
  final Event event;
  final EventStoryScreenArgs args;
  final String Function(DateTime) formatDate;
  final String Function(String) getEventTypeLabel;
  final VoidCallback onTapOpenTorcida;

  const _StoryEventPage({
    required this.event,
    required this.args,
    required this.formatDate,
    required this.getEventTypeLabel,
    required this.onTapOpenTorcida,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = event.imageUrl != null && event.imageUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTapOpenTorcida,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: event.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.primary.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              ),
              errorWidget: (_, __, ___) => _buildPlaceholder(),
            )
          else
            _buildPlaceholder(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    getEventTypeLabel(event.eventType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 6),
                    Text(
                      formatDate(event.eventDate),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (event.location != null && event.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Toque para abrir eventos da torcida',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.25),
      child: Center(
        child: Icon(
          Icons.event_rounded,
          size: 80,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
