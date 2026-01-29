import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../constants/app_colors.dart';
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
          // Header
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.sports_soccer, color: AppColors.textLight);
                  },
                ),
                const Spacer(),
                Text(
                  _authService.userEmail ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PerfilScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('Perfil', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sair', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Minhas Torcidas e Times - No início da página
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

                    // Título de boas-vindas (após as torcidas)
                    Text(
                      'BEM-VINDO!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasMemberships
                          ? 'Selecione uma torcida ou time para acessar.'
                          : 'Comece criando ou entrando em uma torcida.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Solicitações Pendentes
                    if (hasPendingRequests) ...[
                      Row(
                        children: [
                          Icon(Icons.access_time, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Solicitações Pendentes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._pendingRequests.asMap().entries.map((entry) {
                        return _buildPendingRequestCard(entry.value, entry.key);
                      }),
                      const SizedBox(height: 24),
                    ],

                    // Ações Rápidas
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildQuickActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'CRIAR TORCIDA',
                          subtitle: 'Cadastre sua torcida organizada',
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CriarTorcidaScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickActionCard(
                          icon: Icons.sports_soccer,
                          title: 'CRIAR TIME',
                          subtitle: 'Crie seu time amador',
                          color: AppColors.lightGreen,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CriarTimeScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickActionCard(
                          icon: Icons.search,
                          title: 'BUSCAR',
                          subtitle: 'Encontre torcidas e times',
                          color: AppColors.hubBlue,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BuscarTorcidasScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickActionCard(
                          icon: Icons.group_add,
                          title: 'CONVITE',
                          subtitle: 'Use código de convite',
                          color: AppColors.textSecondary,
                          isDashed: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EntrarTorcidaScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      margin: EdgeInsets.only(bottom: index < totalCount - 1 ? 12 : 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/minha-torcida/$fanClubId',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
      margin: EdgeInsets.only(bottom: index < _pendingRequests.length - 1 ? 12 : 0),
      elevation: 2,
      color: AppColors.warning.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDashed = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDashed
            ? BorderSide(
                color: AppColors.textSecondary.withOpacity(0.2),
                style: BorderStyle.solid,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDashed
                      ? AppColors.textSecondary.withOpacity(0.1)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDashed ? AppColors.textSecondary : color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDashed ? AppColors.textSecondary : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            Icon(Icons.shield, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Minhas Torcidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.textSecondary.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.shield,
                    size: 32,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma torcida ainda',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
            Icon(Icons.sports_soccer, color: AppColors.lightGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Meus Times',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.textSecondary.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 32,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum time ainda',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

}

