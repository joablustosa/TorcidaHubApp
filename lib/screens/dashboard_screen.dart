import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../services/event_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../widgets/torcida_hub_bottom_nav.dart';
import 'perfil_screen.dart';
import 'auth/login_screen.dart';
import 'criar_torcida_screen.dart';
import 'criar_time_screen.dart';
import 'buscar_torcidas_screen.dart';
import 'entrar_torcida_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthServiceSupabase();
  bool _isLoading = true;
  List<Map<String, dynamic>> _memberships = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Event> _upcomingEvents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_authService.userId == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

      await Future.wait([
        _fetchMemberships(),
        _fetchPendingRequests(),
      ]);
      await _fetchUpcomingEvents();
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

  Future<void> _fetchMemberships() async {
    try {
      print('Dashboard: Buscando memberships para user_id: ${_authService.userId}');
      
      // Query exatamente como no curl fornecido
      final response = await SupabaseService.client
          .from('fan_club_members')
          .select('''
            id,
            position,
            fan_club_id,
            fan_clubs!inner (
              id,
              name,
              team_name,
              logo_url,
              club_type,
              deleted_at
            )
          ''')
          .eq('user_id', _authService.userId!)
          .eq('status', 'active')
          .isFilter('fan_clubs.deleted_at', null);

      print('Dashboard: Response recebido: sucesso');
      
      final List<dynamic> data = (response as List? ?? []);
      print('Dashboard: Total de memberships retornadas: ${data.length}');
      
      // Processar dados recebidos - fan_clubs vem como objeto único (não array) devido ao !inner
      final processedData = <Map<String, dynamic>>[];
      
      for (var item in data) {
        try {
          final membership = Map<String, dynamic>.from(item);
          final fanClub = membership['fan_clubs'];
          
          if (fanClub == null) {
            print('Dashboard: Membership ${membership['id']} sem fan_clubs');
            continue;
          }
          
          // Com !inner, fan_clubs vem como objeto único (Map)
          Map<String, dynamic>? fanClubMap;
          if (fanClub is Map<String, dynamic>) {
            fanClubMap = fanClub;
          } else if (fanClub is List && fanClub.isNotEmpty) {
            // Fallback caso venha como array
            fanClubMap = Map<String, dynamic>.from(fanClub.first);
          }
          
          if (fanClubMap == null) {
            print('Dashboard: Membership ${membership['id']} - fan_clubs não é um Map válido');
            continue;
          }
          
          // Garantir que fan_clubs está como Map no membership
          membership['fan_clubs'] = fanClubMap;
          processedData.add(membership);
          
          print('Dashboard: Membership válida - Torcida: ${fanClubMap['name']}, Time: ${fanClubMap['team_name']}, Posição: ${membership['position']}');
        } catch (e, stackTrace) {
          print('Dashboard: Erro ao processar membership: $e');
          print('Stack trace: $stackTrace');
          continue;
        }
      }
      
      print('Dashboard: Total de ${processedData.length} memberships processadas');
      
      if (mounted) {
        setState(() {
          _memberships = processedData;
        });
      }
    } catch (e, stackTrace) {
      print('Erro ao buscar membros: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _memberships = [];
        });
      }
    }
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final response = await SupabaseService.client
          .from('membership_requests')
          .select('''
            id,
            fan_club_id,
            status,
            created_at,
            fan_clubs!inner (
              id,
              name,
              team_name,
              logo_url,
              club_type
            )
          ''')
          .eq('user_id', _authService.userId!)
          .eq('status', 'pending');

      final List<dynamic> data = (response as List? ?? []);
      if (mounted) {
        setState(() {
          _pendingRequests = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Erro ao buscar solicitações: $e');
      if (mounted) {
        setState(() {
          _pendingRequests = [];
        });
      }
    }
  }

  Future<void> _fetchUpcomingEvents() async {
    if (_memberships.isEmpty || _authService.userId == null) {
      if (mounted) setState(() => _upcomingEvents = []);
      return;
    }
    try {
      final now = DateTime.now();
      final List<Event> all = [];
      for (var m in _memberships) {
        final fanClubId = m['fan_club_id'] as String?;
        if (fanClubId == null) continue;
        final list = await EventService.getEvents(
          fanClubId: fanClubId,
          userId: _authService.userId,
        );
        all.addAll(list.where((e) => e.eventDate.isAfter(now) || e.eventDate.isAtSameMomentAs(now)));
      }
      all.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      if (mounted) {
        setState(() {
          _upcomingEvents = all.take(20).toList();
        });
      }
    } catch (e) {
      print('Erro ao buscar eventos: $e');
      if (mounted) setState(() => _upcomingEvents = []);
    }
  }

  bool _isAmateurTeam(String? clubType) {
    if (clubType == null) return false;
    return ['amateur_team', 'neighborhood_team', 'school_team', 'work_team']
        .contains(clubType);
  }

  String? _getClubType(Map<String, dynamic> membership) {
    final fanClub = membership['fan_clubs'] as Map<String, dynamic>?;
    return fanClub?['club_type'] as String?;
  }

  String _getClubName(Map<String, dynamic> membership) {
    final fanClub = membership['fan_clubs'] as Map<String, dynamic>?;
    return fanClub?['name'] as String? ?? 'Torcida';
  }

  String? _getTeamName(Map<String, dynamic> membership) {
    final fanClub = membership['fan_clubs'] as Map<String, dynamic>?;
    return fanClub?['team_name'] as String?;
  }

  String? _getLogoUrl(Map<String, dynamic> membership) {
    final fanClub = membership['fan_clubs'] as Map<String, dynamic>?;
    return fanClub?['logo_url'] as String?;
  }

  String _getFanClubId(Map<String, dynamic> membership) {
    return membership['fan_club_id'] as String;
  }

  String? _getFanClubLogoUrl(String fanClubId) {
    try {
      final m = _memberships.firstWhere(
        (m) => (m['fan_club_id'] as String?) == fanClubId,
      );
      final fanClub = m['fan_clubs'] as Map<String, dynamic>?;
      return fanClub?['logo_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Widget _buildEventCirclePlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.12),
      child: Icon(
        Icons.event_rounded,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }

  Widget _buildEventCircleImage(Event event) {
    final imageUrl = event.imageUrl != null && event.imageUrl!.trim().isNotEmpty
        ? event.imageUrl
        : _getFanClubLogoUrl(event.fanClubId);
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return _buildEventCirclePlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: 72,
      height: 72,
      placeholder: (_, __) => _buildEventCirclePlaceholder(),
      errorWidget: (_, __, ___) => _buildEventCirclePlaceholder(),
    );
  }

  Widget _buildEventsHorizontalList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Próximos eventos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  height: 112,
                  width: 80,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/minha-torcida/${event.fanClubId}',
                        arguments: {'tabIndex': 1},
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildEventCircleImage(event),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRect(
                            child: SizedBox(
                              width: 80,
                              child: Text(
                                event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getPosition(Map<String, dynamic> membership) {
    return membership['position'] as String;
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  /// Exibe "Nome (Apelido)" ou fallback para email/Usuário.
  String get _userDisplayName {
    final p = _authService.currentProfile;
    final name = (p?.fullName ?? '').trim().isNotEmpty ? p!.fullName!.trim() : null;
    final nickname = (p?.nickname ?? '').trim().isNotEmpty ? p?.nickname!.trim() : null;
    if (name != null && nickname != null) return '$name ($nickname)';
    if (name != null) return name;
    if (nickname != null) return '($nickname)';
    return _authService.userEmail ?? 'Usuário';
  }

  /// Iniciais do nome para avatar (ex: "João Silva" -> "JS").
  String get _userInitials {
    final name = _authService.currentProfile?.fullName?.trim() ?? _authService.userEmail ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
      final b = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
      return '$a$b';
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name[0].toUpperCase();
  }

  Widget _buildUserAvatar() {
    final avatarUrl = _authService.currentProfile?.avatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.textLight.withOpacity(0.2),
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.textLight.withOpacity(0.25),
      child: Text(
        _userInitials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.textLight,
            ),
          ),
        ),
      );
    }

    final fanClubMemberships = _memberships.where((m) {
      return !_isAmateurTeam(_getClubType(m));
    }).toList();

    final teamMemberships = _memberships.where((m) {
      return _isAmateurTeam(_getClubType(m));
    }).toList();

    final hasFanClubs = fanClubMemberships.isNotEmpty;
    final hasTeams = teamMemberships.isNotEmpty;
    final hasMemberships = _memberships.isNotEmpty;
    final hasPendingRequests = _pendingRequests.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header moderno com gradiente e avatar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 14,
              left: 20,
              right: 12,
            ),
            child: Row(
              children: [
                // Avatar (foto ou iniciais)
                _buildUserAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Olá,',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userDisplayName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  color: AppColors.textLight,
                  tooltip: 'Sair',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.textLight.withOpacity(0.15),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero / mensagem em card discreto
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.12),
                            AppColors.lightGreen.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasMemberships ? Icons.touch_app_rounded : Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasMemberships
                                  ? 'Selecione uma torcida ou time para acessar.'
                                  : 'Comece criando ou entrando em uma torcida.',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Próximos eventos (lista horizontal estilo status)
                    if (_upcomingEvents.isNotEmpty) ...[
                      _buildEventsHorizontalList(),
                      const SizedBox(height: 24),
                    ],

                    // Minhas Torcidas e Times
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildFanClubsSection(hasFanClubs, fanClubMemberships)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTeamsSection(hasTeams, teamMemberships)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFanClubsSection(hasFanClubs, fanClubMemberships),
                                  const SizedBox(height: 24),
                                  _buildTeamsSection(hasTeams, teamMemberships),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Solicitações Pendentes
                    if (hasPendingRequests) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.schedule_rounded, color: AppColors.warning, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Solicitações Pendentes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_pendingRequests.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ..._pendingRequests.asMap().entries.map((entry) {
                        return _buildPendingRequestCard(entry.value, entry.key);
                      }),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TorcidaHubBottomNav(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CriarTimeScreen()),
              );
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuscarTorcidasScreen()),
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CriarTorcidaScreen()),
              );
              break;
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EntrarTorcidaScreen()),
              );
              break;
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildMembershipCard(
    Map<String, dynamic> membership,
    int index,
    bool isTeam,
    int totalCount,
  ) {
    final clubName = _getClubName(membership);
    final teamName = _getTeamName(membership);
    final logoUrl = _getLogoUrl(membership);
    final position = _getPosition(membership);
    final fanClubId = _getFanClubId(membership);
    // Formatar posição para exibição
    String positionLabel;
    if (position == 'presidente') {
      positionLabel = isTeam ? 'Capitão' : 'Presidente';
    } else if (position == 'diretoria') {
      positionLabel = 'Diretoria';
    } else {
      // Capitalizar primeira letra
      positionLabel = position.isNotEmpty
          ? position[0].toUpperCase() + position.substring(1)
          : position;
    }

    return Card(
      margin: EdgeInsets.only(bottom: index < totalCount - 1 ? 14 : 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/minha-torcida/$fanClubId',
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              if (logoUrl != null && logoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    logoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isTeam
                              ? AppColors.lightGreen.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Erro ao carregar logo: $error');
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isTeam
                              ? AppColors.lightGreen.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isTeam ? Icons.sports_soccer : Icons.shield,
                          color: isTeam ? AppColors.lightGreen : AppColors.primary,
                          size: 28,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isTeam
                        ? AppColors.lightGreen.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTeam ? Icons.sports_soccer : Icons.shield,
                    color: isTeam ? AppColors.lightGreen : AppColors.primary,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (teamName != null && !isTeam) ...[
                      const SizedBox(height: 2),
                      Text(
                        teamName,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTeam
                            ? AppColors.lightGreen.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        positionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isTeam ? AppColors.lightGreen : AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> request, int index) {
    final fanClub = request['fan_clubs'] as Map<String, dynamic>?;
    final clubName = fanClub?['name'] as String? ?? 'Torcida';
    final teamName = fanClub?['team_name'] as String?;
    final logoUrl = fanClub?['logo_url'] as String?;

    return Card(
      margin: EdgeInsets.only(bottom: index < _pendingRequests.length - 1 ? 14 : 0),
      elevation: 0,
      color: AppColors.warning.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            if (logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  logoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(0.75),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield,
                        color: AppColors.warning,
                        size: 28,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield,
                  color: AppColors.warning,
                  size: 28,
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clubName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (teamName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Aguardando aprovação',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanClubsSection(bool hasFanClubs, List<Map<String, dynamic>> memberships) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Minhas Torcidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (memberships.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${memberships.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (hasFanClubs)
          ...memberships.asMap().entries.map((entry) {
            return _buildMembershipCard(
              entry.value,
              entry.key,
              false,
              memberships.length,
            );
          })
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.15),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 40,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma torcida ainda',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTeamsSection(bool hasTeams, List<Map<String, dynamic>> memberships) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.sports_soccer_rounded, color: AppColors.lightGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Meus Times',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (memberships.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${memberships.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (hasTeams)
          ...memberships.asMap().entries.map((entry) {
            return _buildMembershipCard(
              entry.value,
              entry.key,
              true,
              memberships.length,
            );
          })
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.15),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  size: 40,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhum time ainda',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

}

