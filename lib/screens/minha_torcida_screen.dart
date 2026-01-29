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

class _MinhaTorcidaScreenState extends State<MinhaTorcidaScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthServiceSupabase();
  late TabController _tabController;
  bool _isLoading = true;
  FanClub? _fanClub;
  FanClubMember? _member;
  Profile? _profile;
  int _memberCount = 0;
  Map<String, bool> _permissions = {};
  bool _permissionsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      // Tab changed
    });
    _loadData();
  }

  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'feed';
      case 1:
        return 'eventos';
      case 2:
        return 'membros';
      case 3:
        return 'albuns';
      case 4:
        return 'gamificacao';
      case 5:
        return 'config';
      default:
        return 'feed';
    }
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_fanClub == null || _member == null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Torcida não encontrada'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Torcida não encontrada'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
                child: const Text('Voltar ao Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          _fanClub!.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textLight,
          labelColor: AppColors.textLight,
          unselectedLabelColor: AppColors.textLightSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Feed'),
            Tab(icon: Icon(Icons.event), text: 'Eventos'),
            Tab(icon: Icon(Icons.people), text: 'Membros'),
            Tab(icon: Icon(Icons.photo_library), text: 'Álbuns'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Ranking'),
            Tab(icon: Icon(Icons.settings), text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(),
          _buildEventosTab(),
          _buildMembrosTab(),
          _buildAlbunsTab(),
          _buildGamificacaoTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
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
    return FutureBuilder<List<Post>>(
      future: PostService.getPosts(
        fanClubId: widget.fanClubId,
        limit: 20,
      ),
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
            return Column(
              children: [
                PostCard(
                  post: post,
                  isAdmin: _isAdmin,
                  canEdit: _hasPermission('editar_publicacoes') || post.userId == _authService.userId,
                  canDelete: _hasPermission('deletar_publicacoes') || post.userId == _authService.userId,
                  onLike: () async {
                    await PostService.likePost(post.id, _authService.userId!);
                    _loadData();
                  },
                  onUnlike: () async {
                    await PostService.unlikePost(post.id, _authService.userId!);
                    _loadData();
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
                      _loadData();
                    }
                  },
                  onComment: () {
                    setState(() {
                      // Toggle comentários
                    });
                  },
                ),
                // Seção de comentários
                if (post.allowComments ?? true)
                  CommentSection(
                    postId: post.id,
                    fanClubId: widget.fanClubId,
                    canModerateComments: _hasPermission('moderar_comentarios'),
                    onNewComment: () {
                      _loadData();
                    },
                  ),
              ],
            );
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
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasPermission('criar_eventos'))
            ElevatedButton.icon(
              onPressed: () {
                _showCreateEventDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Criar Evento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          const SizedBox(height: 16),
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
                    'Erro ao carregar eventos',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Nenhum evento agendado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (upcomingEvents.isNotEmpty) ...[
              const Text(
                'Próximos Eventos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...upcomingEvents.map((event) {
                return EventCard(
                  event: event,
                  isAdmin: _isAdmin,
                  onRegister: () async {
                    try {
                      final paymentData = await EventService.registerForEvent(
                        eventId: event.id,
                        userId: _authService.userId!,
                      );

                      if (mounted) {
                        if (event.isPaid && paymentData != null) {
                          // Mostrar diálogo de pagamento PIX
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
                                _loadData();
                              },
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Inscrição realizada com sucesso!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadData();
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao se inscrever: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Inscrição cancelada'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        _loadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao cancelar: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  onViewDetails: () {
                    // TODO: Implementar detalhes do evento
                  },
                );
              }),
            ],
            if (pastEvents.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Eventos Passados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...pastEvents.map((event) {
                return EventCard(
                  event: event,
                  isAdmin: _isAdmin,
                  onViewDetails: () {
                    // TODO: Implementar detalhes do evento
                  },
                );
              }),
            ],
          ],
        );
      },
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
        padding: const EdgeInsets.all(16),
        children: [
          // Carteirinha Digital
          if (_fanClub != null && _member != null && _profile != null)
            DigitalCard(
              member: _member!,
              fanClub: _fanClub!,
              profile: _profile,
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total de Membros',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_memberCount',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasPermission('criar_albuns'))
            ElevatedButton.icon(
              onPressed: () {
                _showCreateAlbumDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Criar Álbum'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          const SizedBox(height: 16),
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(16),
        children: [
          // Card de estatísticas do usuário
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 24),
          const Text(
            'Ranking da Torcida',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar Informações'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implementar editar torcida
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Gerenciar Membros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implementar gerenciar membros
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implementar configurações
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFanClubHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_fanClub!.logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _fanClub!.logoUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 40,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _fanClub!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_fanClub!.teamName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _fanClub!.teamName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(Icons.people, '$_memberCount', 'Membros'),
                const SizedBox(width: 32),
                _buildStatItem(Icons.star, '${_member?.points ?? 0}', 'Pontos'),
              ],
            ),
          ],
        ),
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

