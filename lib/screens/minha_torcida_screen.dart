import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../services/post_service.dart';
import '../services/event_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_form.dart';
import '../widgets/event_card.dart';
import '../widgets/ranking_list.dart';
import '../widgets/digital_card.dart';
import '../services/album_service.dart';
import '../services/permissions_service.dart';
import '../widgets/comment_section.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/create_album_dialog.dart';
import '../widgets/pix_payment_dialog.dart';
import 'album_detail_screen.dart';
import 'dashboard_screen.dart';

class MinhaTorcidaScreen extends StatefulWidget {
  final String fanClubId;

  const MinhaTorcidaScreen({
    super.key,
    required this.fanClubId,
  });

  @override
  State<MinhaTorcidaScreen> createState() => _MinhaTorcidaScreenState();
}

class _MinhaTorcidaScreenState extends State<MinhaTorcidaScreen> {
  final _authService = AuthServiceSupabase();
  int _currentTabIndex = 0;
  bool _isLoading = true;
  FanClub? _fanClub;
  FanClubMember? _member;
  Profile? _profile;
  int _memberCount = 0;
  Map<String, bool> _permissions = {};
  bool _permissionsLoading = true;
  /// ID da publicação cuja seção de comentários está expandida (evita "Nenhum comentário ainda" sem contexto).
  String? _expandedCommentsPostId;
  /// Future dos posts em cache para não recarregar a lista ao abrir/fechar comentários.
  Future<List<Post>>? _postsFuture;
  /// IDs de eventos em que o usuário se inscreveu nesta sessão (evita recarregar a tela).
  final Set<String> _registeredEventIds = {};
  /// IDs de eventos em que o usuário cancelou a inscrição nesta sessão.
  final Set<String> _cancelledEventIds = {};

  @override
  void initState() {
    super.initState();
    _postsFuture = PostService.getPosts(
      fanClubId: widget.fanClubId,
      limit: 20,
      currentUserId: _authService.userId,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchFanClub();
      await _fetchMember();
      await _fetchProfile();
      await _fetchMemberCount();
      await _fetchPermissions();
    } catch (e) {
      print('Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshPosts() {
    setState(() {
      _postsFuture = PostService.getPosts(
        fanClubId: widget.fanClubId,
        limit: 20,
        currentUserId: _authService.userId,
      );
    });
  }

  Future<void> _fetchFanClub() async {
    try {
      final response = await SupabaseService.client
          .from('fan_clubs')
          .select()
          .eq('id', widget.fanClubId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _fanClub = FanClub.fromJson(Map<String, dynamic>.from(response));
        });
      }
    } catch (e) {
      print('Erro ao buscar torcida: $e');
    }
  }

  Future<void> _fetchMember() async {
    if (_authService.userId == null) return;

    try {
      final response = await SupabaseService.client
          .from('fan_club_members')
          .select()
          .eq('fan_club_id', widget.fanClubId)
          .eq('user_id', _authService.userId!)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _member = FanClubMember.fromJson(Map<String, dynamic>.from(response));
        });
      }
    } catch (e) {
      print('Erro ao buscar membro: $e');
    }
  }

  Future<void> _fetchProfile() async {
    if (_authService.userId == null) return;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', _authService.userId!)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _profile = Profile.fromJson(Map<String, dynamic>.from(response));
        });
      }
    } catch (e) {
      print('Erro ao buscar perfil: $e');
    }
  }

  Future<void> _fetchMemberCount() async {
    try {
      final response = await SupabaseService.client
          .from('fan_club_members')
          .select('id')
          .eq('fan_club_id', widget.fanClubId)
          .eq('status', 'active');

      if (response != null) {
        setState(() {
          _memberCount = (response as List).length;
        });
      }
    } catch (e) {
      print('Erro ao contar membros: $e');
    }
  }

  Future<void> _fetchPermissions() async {
    if (_member == null) {
      setState(() {
        _permissionsLoading = false;
      });
      return;
    }

    setState(() {
      _permissionsLoading = true;
    });

    try {
      final permissions = await PermissionsService.getPermissions(
        fanClubId: widget.fanClubId,
        positionName: _member!.position,
      );

      setState(() {
        _permissions = permissions;
        _permissionsLoading = false;
      });
    } catch (e) {
      print('Erro ao buscar permissões: $e');
      setState(() {
        _permissionsLoading = false;
      });
    }
  }

  bool _hasPermission(String permissionKey) {
    if (_member == null) return false;
    return PermissionsService.hasPermission(
      positionName: _member!.position,
      permissions: _permissions,
      permissionKey: permissionKey,
    );
  }

  bool get _isAdmin {
    return _member?.position == 'presidente' ||
        _member?.position == 'diretoria';
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.darkGreen],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.textLight,
            ),
          ),
        ),
      );
    }

    if (_fanClub == null || _member == null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Torcida não encontrada'),
          foregroundColor: AppColors.textLight,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary],
              ),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 20),
                const Text(
                  'Torcida não encontrada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Voltar ao Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _fanClub!.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
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
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildFeedTab(),
          _buildEventosTab(),
          _buildMembrosTab(),
          _buildAlbunsTab(),
          _buildGamificacaoTab(),
          _buildConfigTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (index) => setState(() => _currentTabIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_rounded),
                  label: 'Eventos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_rounded),
                  label: 'Membros',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library_rounded),
                  label: 'Álbuns',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events_rounded),
                  label: 'Ranking',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Config',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        _refreshPosts();
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          // Header da torcida
          _buildFanClubHeader(),
          const SizedBox(height: 24),
          
          // Formulário de criar publicação
          if (_hasPermission('criar_publicacoes') && _authService.userId != null)
            CreatePostForm(
              fanClubId: widget.fanClubId,
              userId: _authService.userId!,
              onPostCreated: (_) {
                _loadData();
              },
            ),
          const SizedBox(height: 16),
          
          // Lista de publicações
          _buildPostsList(),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    final future = _postsFuture ?? PostService.getPosts(
      fanClubId: widget.fanClubId,
      limit: 20,
      currentUserId: _authService.userId,
    );
    return FutureBuilder<List<Post>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar publicações',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Nenhuma publicação ainda.\nSeja o primeiro a compartilhar!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: posts.map((post) {
            final commentsExpanded = (post.allowComments ?? true) &&
                _expandedCommentsPostId == post.id;

            final postCard = PostCard(
              post: post,
              isAdmin: _isAdmin,
              canEdit: _hasPermission('editar_publicacoes') || post.userId == _authService.userId,
              canDelete: _hasPermission('deletar_publicacoes') || post.userId == _authService.userId,
              onLike: () async {
                await PostService.likePost(post.id, _authService.userId!);
                _refreshPosts();
              },
              onUnlike: () async {
                await PostService.unlikePost(post.id, _authService.userId!);
                _refreshPosts();
              },
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir publicação'),
                    content: const Text('Tem certeza que deseja excluir esta publicação?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await PostService.deletePost(post.id);
                  _refreshPosts();
                }
              },
              onComment: () {
                setState(() {
                  _expandedCommentsPostId =
                      _expandedCommentsPostId == post.id ? null : post.id;
                });
              },
              showComments: commentsExpanded,
              embedInCard: !commentsExpanded,
            );

            if (commentsExpanded) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: post.isPinned
                      ? const BorderSide(color: AppColors.primary, width: 2)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    postCard,
                    CommentSection(
                      postId: post.id,
                      fanClubId: widget.fanClubId,
                      canModerateComments: _hasPermission('moderar_comentarios'),
                      onNewComment: _refreshPosts,
                    ),
                  ],
                ),
              );
            }

            return postCard;
          }).toList(),
        );
      },
    );
  }

  Widget _buildEventosTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          if (_hasPermission('criar_eventos'))
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateEventDialog(),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text('Criar Evento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          _buildEventsList(),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return FutureBuilder<List<Event>>(
      future: EventService.getEvents(
        fanClubId: widget.fanClubId,
        userId: _authService.userId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEventosLogoRow(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível carregar os eventos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Tentar novamente'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final events = snapshot.data ?? [];
        final upcomingEvents = events
            .where((e) => e.eventDate.isAfter(DateTime.now()))
            .toList();
        final pastEvents = events
            .where((e) => e.eventDate.isBefore(DateTime.now()))
            .toList();

        if (events.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEventosLogoRow(),
              Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    size: 48,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nenhum evento agendado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Os eventos da torcida aparecerão aqui.\nSe você tiver permissão, crie o primeiro!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_hasPermission('criar_eventos')) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateEventDialog(),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Criar evento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventosLogoRow(
              upcomingCount: upcomingEvents.length,
              pastCount: pastEvents.length,
            ),
            const SizedBox(height: 24),
            if (upcomingEvents.isNotEmpty) ...[
              _buildSectionHeader(
                Icons.upcoming_rounded,
                'Próximos eventos',
                upcomingEvents.length,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: upcomingEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final event = upcomingEvents[index];
                    return SizedBox(
                      width: 300,
                      child: EventCard(
                        event: event,
                        isAdmin: _isAdmin,
                        overrideUserRegistered: (event.userRegistered ||
                                _registeredEventIds.contains(event.id)) &&
                            !_cancelledEventIds.contains(event.id),
                        onRegister: () async {
                    try {
                      final paymentData = await EventService.registerForEvent(
                        eventId: event.id,
                        userId: _authService.userId!,
                      );

                      if (mounted) {
                        setState(() {
                          _registeredEventIds.add(event.id);
                          _cancelledEventIds.remove(event.id);
                        });
                        if (event.isPaid && paymentData != null) {
                          showDialog(
                            context: context,
                            builder: (context) => PixPaymentDialog(
                              orderId: paymentData['order_id'] as String? ?? '',
                              qrCode: paymentData['qr_code'] as String? ?? '',
                              qrCodeUrl: paymentData['qr_code_url'] as String?,
                              expiresAt: paymentData['expires_at'] != null
                                  ? DateTime.parse(paymentData['expires_at'] as String)
                                  : DateTime.now().add(const Duration(minutes: 30)),
                              baseAmount: event.price,
                              fee: (event.price * 0.0499),
                              total: event.price + (event.price * 0.0499),
                              itemName: event.title,
                              onPaymentConfirmed: () {
                                // Sem recarregar a tela; estado local já atualizado
                              },
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Inscrição realizada com sucesso!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        final msg = e.toString();
                        final isAlreadyRegistered = msg.contains('ALREADY_REGISTERED');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAlreadyRegistered
                                  ? 'Você já está inscrito neste evento.'
                                  : 'Erro ao se inscrever: ${e.toString()}',
                            ),
                            backgroundColor: isAlreadyRegistered
                                ? AppColors.primary
                                : AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        if (isAlreadyRegistered) {
                          setState(() {
                            _registeredEventIds.add(event.id);
                            _cancelledEventIds.remove(event.id);
                          });
                        }
                      }
                    }
                  },
                  onCancelRegistration: () async {
                    try {
                      await EventService.cancelRegistration(
                        eventId: event.id,
                        userId: _authService.userId!,
                      );
                      if (mounted) {
                        setState(() {
                          _registeredEventIds.remove(event.id);
                          _cancelledEventIds.add(event.id);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Inscrição cancelada'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao cancelar: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  onViewDetails: () {
                    // TODO: Implementar detalhes do evento
                  },
                ),
                    );
                  },
                ),
              ),
            ],
            if (pastEvents.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(
                Icons.history_rounded,
                'Eventos passados',
                pastEvents.length,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: pastEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final event = pastEvents[index];
                    return SizedBox(
                      width: 300,
                      child: EventCard(
                        event: event,
                        isAdmin: _isAdmin,
                        overrideUserRegistered: (event.userRegistered ||
                                _registeredEventIds.contains(event.id)) &&
                            !_cancelledEventIds.contains(event.id),
                        onViewDetails: () {
                          // TODO: Implementar detalhes do evento
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEventosLogoRow({int? upcomingCount, int? pastCount}) {
    if (_fanClub == null) return const SizedBox.shrink();
    const double logoSize = 72;
    final hasCounts = upcomingCount != null && pastCount != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo à esquerda, sem fundo
          _fanClub!.logoUrl != null && _fanClub!.logoUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    _fanClub!.logoUrl!,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildEventosLogoPlaceholder(logoSize),
                  ),
                )
              : _buildEventosLogoPlaceholder(logoSize),
          const SizedBox(width: 16),
          // Texto à direita
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Eventos da Torcida',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fanClub!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (hasCounts) ...[
                  Row(
                    children: [
                      _buildEventosIndicator(
                        Icons.upcoming_rounded,
                        '$upcomingCount próximo${upcomingCount != 1 ? 's' : ''}',
                      ),
                      const SizedBox(width: 12),
                      _buildEventosIndicator(
                        Icons.history_rounded,
                        '$pastCount no histórico',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Deslize horizontalmente para ver todos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.9),
                    ),
                  ),
                ] else
                  Text(
                    'Confira os próximos encontros e o histórico abaixo.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventosIndicator(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEventosLogoPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.shield_rounded,
        size: size * 0.5,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEventDialog(
        fanClubId: widget.fanClubId,
        fanClubName: _fanClub?.name ?? '',
        onEventCreated: () {
          _loadData();
        },
      ),
    );
  }

  Widget _buildMembrosTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          // Carteirinha Digital
          if (_fanClub != null && _member != null && _profile != null)
            DigitalCard(
              member: _member!,
              fanClub: _fanClub!,
              profile: _profile,
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.people_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Total de Membros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_memberCount',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Lista de membros em breve...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbunsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          if (_hasPermission('criar_albuns')) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateAlbumDialog(),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('Criar Álbum'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildAlbumsList(),
        ],
      ),
    );
  }

  Widget _buildAlbumsList() {
    return FutureBuilder<List<Album>>(
      future: AlbumService.getAlbums(widget.fanClubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar álbuns',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final albums = snapshot.data ?? [];

        if (albums.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Nenhum álbum criado ainda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.12),
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AlbumDetailScreen(
                        album: album,
                        canUploadPhotos: _authService.userId == album.createdBy,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: AppColors.background,
                        ),
                        child: album.coverPhotoUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  album.coverPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.photo_library,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.photo_library,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${album.photoCount} fotos',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateAlbumDialog() async {
    // Buscar eventos para o dropdown
    final events = await EventService.getEvents(
      fanClubId: widget.fanClubId,
      userId: _authService.userId,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => CreateAlbumDialog(
        fanClubId: widget.fanClubId,
        events: events,
        onAlbumCreated: () {
          _loadData();
        },
      ),
    );
  }

  Widget _buildGamificacaoTab() {
    if (_member == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          // Card de estatísticas do usuário – estilo dashboard
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.12),
              ),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seu nível atual',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _member!.badgeLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Pontos',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_member!.points}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ranking da Torcida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RankingList(
            fanClubId: widget.fanClubId,
            currentUserId: _authService.userId,
            limit: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    if (!_isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Apenas administradores podem acessar as configurações.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        _buildConfigTile(
          icon: Icons.edit_rounded,
          title: 'Editar Informações',
          onTap: () {
            // TODO: Implementar editar torcida
          },
        ),
        const SizedBox(height: 12),
        _buildConfigTile(
          icon: Icons.people_rounded,
          title: 'Gerenciar Membros',
          onTap: () {
            // TODO: Implementar gerenciar membros
          },
        ),
        const SizedBox(height: 12),
        _buildConfigTile(
          icon: Icons.settings_rounded,
          title: 'Configurações',
          onTap: () {
            // TODO: Implementar configurações
          },
        ),
      ],
    );
  }

  Widget _buildConfigTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFanClubHeader() {
    final hasCover = _fanClub!.coverUrl != null && _fanClub!.coverUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: hasCover
              ? DecorationImage(
                  image: NetworkImage(_fanClub!.coverUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: LinearGradient(
            colors: hasCover
                ? [
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.8),
                  ]
                : [
                    AppColors.primary,
                    AppColors.darkGreen,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha: logo à esquerda | Membros e Pontos à direita
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo à esquerda
                if (_fanClub!.logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _fanClub!.logoUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildLogoPlaceholder(72);
                      },
                    ),
                  )
                else
                  _buildLogoPlaceholder(72),
                const SizedBox(width: 16),
                // Membros e Pontos ao lado da logo
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildStatItem(
                        Icons.people_rounded,
                        '$_memberCount',
                        'Membros',
                      ),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        Icons.star_rounded,
                        '${_member?.points ?? 0}',
                        'Pontos',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _fanClub!.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (_fanClub!.teamName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _fanClub!.teamName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
            if (_fanClub!.description != null &&
                _fanClub!.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _fanClub!.description!.trim(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.35,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.shield_rounded,
        size: 36,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

