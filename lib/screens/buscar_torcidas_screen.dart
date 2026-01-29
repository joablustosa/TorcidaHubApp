import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'minha_torcida_screen.dart';
import 'entrar_torcida_screen.dart';

class BuscarTorcidasScreen extends StatefulWidget {
  const BuscarTorcidasScreen({super.key});

  @override
  State<BuscarTorcidasScreen> createState() => _BuscarTorcidasScreenState();
}

class _BuscarTorcidasScreenState extends State<BuscarTorcidasScreen> {
  final _authService = AuthServiceSupabase();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<FanClub> _fanClubs = [];
  List<String> _userMemberships = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  String _activeTab = 'all';
  String? _joiningClubId;
  String? _requestingClubId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchFanClubs(),
        _fetchUserMemberships(),
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

  Future<void> _fetchFanClubs() async {
    try {
      var query = SupabaseService.client
          .from('fan_clubs')
          .select();

      if (_searchController.text.trim().isNotEmpty) {
        final searchTerm = _searchController.text.trim();
        query = query.or(
          'team_name.ilike.%$searchTerm%,name.ilike.%$searchTerm%,city.ilike.%$searchTerm%',
        );
      }

      final response = await query.order('name');

      if (response != null) {
        final List<dynamic> data = response as List<dynamic>;
        List<FanClub> clubs = data
            .map((item) => FanClub.fromJson(item as Map<String, dynamic>))
            .toList();

        // Filtrar por visibilidade
        final userId = _authService.userId;
        clubs = clubs.where((club) {
          if (userId != null && club.createdBy == userId) {
            return true;
          }
          if (club.isOfficial == true) {
            return club.isVerified;
          }
          return true;
        }).toList();

        // Filtrar por aba
        if (_activeTab == 'torcidas') {
          clubs = clubs.where((club) => !_isAmateurTeam(club.clubType)).toList();
        } else if (_activeTab == 'times') {
          clubs = clubs.where((club) => _isAmateurTeam(club.clubType)).toList();
        }

        // Contagem de membros será feita no widget quando necessário

        setState(() {
          _fanClubs = clubs;
        });
      }
    } catch (e) {
      print('Erro ao buscar torcidas: $e');
    }
  }

  Future<void> _fetchUserMemberships() async {
    if (_authService.userId == null) return;

    try {
      final response = await SupabaseService.client
          .from('fan_club_members')
          .select('fan_club_id')
          .eq('user_id', _authService.userId!)
          .eq('status', 'active');

      if (response != null) {
        setState(() {
          _userMemberships = (response as List<dynamic>)
              .map((item) => (item as Map<String, dynamic>)['fan_club_id'] as String)
              .toList();
        });
      }
    } catch (e) {
      print('Erro ao buscar membros: $e');
    }
  }

  Future<void> _fetchPendingRequests() async {
    if (_authService.userId == null) return;

    try {
      final response = await SupabaseService.client
          .from('membership_requests')
          .select('fan_club_id, status')
          .eq('user_id', _authService.userId!);

      if (response != null) {
        setState(() {
          _pendingRequests = (response as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Erro ao buscar solicitações: $e');
    }
  }

  bool _isAmateurTeam(String? clubType) {
    if (clubType == null) return false;
    return ['amateur_team', 'neighborhood_team', 'school_team', 'work_team']
        .contains(clubType);
  }

  Future<void> _handleJoin(FanClub club) async {
    if (_authService.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para entrar em uma torcida'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_userMemberships.contains(club.id)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MinhaTorcidaScreen(fanClubId: club.id),
        ),
      );
      return;
    }

    if (club.isPublic != true || club.joinMode != 'open') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta torcida não permite entrada direta'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _joiningClubId = club.id;
    });

    try {
      // Gerar número de registro
      final regNumberResponse = await SupabaseService.client
          .rpc('generate_registration_number', params: {'_fan_club_id': club.id});

      String regNumber = regNumberResponse.toString();
      if (regNumberResponse is Map) {
        regNumber = regNumberResponse['data']?.toString() ?? 
            '00001-${DateTime.now().year.toString().substring(2)}';
      }

      // Adicionar como membro
      await SupabaseService.client.from('fan_club_members').insert({
        'fan_club_id': club.id,
        'user_id': _authService.userId,
        'position': 'membro',
        'status': 'active',
        'registration_number': regNumber,
        'badge_level': 'bronze',
        'points': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você entrou na ${club.name}!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MinhaTorcidaScreen(fanClubId: club.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao entrar na torcida: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningClubId = null;
        });
      }
    }
  }

  Future<void> _handleRequestJoin(FanClub club) async {
    if (_authService.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para solicitar entrada'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _requestingClubId = club.id;
    });

    try {
      await SupabaseService.client.from('membership_requests').insert({
        'fan_club_id': club.id,
        'user_id': _authService.userId,
        'message': '',
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação enviada! Aguarde aprovação do administrador.'),
            backgroundColor: AppColors.success,
          ),
        );
        await _fetchPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao solicitar entrada: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestingClubId = null;
        });
      }
    }
  }

  Widget _buildActionButton(FanClub club) {
    final isMember = _userMemberships.contains(club.id);
    final isJoining = _joiningClubId == club.id;
    final isRequesting = _requestingClubId == club.id;
    final pendingRequest = _pendingRequests.firstWhere(
      (r) => r['fan_club_id'] == club.id,
      orElse: () => {},
    );

    if (isMember) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MinhaTorcidaScreen(fanClubId: club.id),
              ),
            );
          },
          child: const Text('Acessar Torcida'),
        ),
      );
    }

    if (pendingRequest.isNotEmpty) {
      if (pendingRequest['status'] == 'pending') {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Aguardando aprovação'),
              ],
            ),
          ),
        );
      }
      if (pendingRequest['status'] == 'rejected') {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Solicitação recusada'),
          ),
        );
      }
    }

    if (club.isPublic != true) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EntrarTorcidaScreen()),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 16),
              const SizedBox(width: 8),
              const Text('Requer convite'),
            ],
          ),
        ),
      );
    }

    switch (club.joinMode) {
      case 'open':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isJoining ? null : () => _handleJoin(club),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: isJoining
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 16),
                      const SizedBox(width: 8),
                      const Text('Entrar na Torcida'),
                    ],
                  ),
          ),
        );

      case 'request':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isRequesting ? null : () => _handleRequestJoin(club),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.hubBlue,
            ),
            child: isRequesting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, size: 16),
                      const SizedBox(width: 8),
                      const Text('Solicitar entrada'),
                    ],
                  ),
          ),
        );

      case 'invite_only':
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EntrarTorcidaScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number, size: 16),
                const SizedBox(width: 8),
                const Text('Entrar com convite'),
              ],
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Buscar Torcidas e Times'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, time ou cidade...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ),

          // Abas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('all', 'Todos', Icons.list),
                ),
                Expanded(
                  child: _buildTabButton('torcidas', 'Torcidas', Icons.shield),
                ),
                Expanded(
                  child: _buildTabButton('times', 'Times', Icons.sports_soccer),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Lista de resultados
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _fanClubs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _fanClubs.length,
                          itemBuilder: (context, index) {
                            return _buildFanClubCard(_fanClubs[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String value, String label, IconData icon) {
    final isActive = _activeTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = value;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.textLight : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.textLight : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanClubCard(FanClub club) {
    final modeInfo = _getJoinModeLabel(club);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: club.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            club.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.shield,
                                color: AppColors.primary,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.shield,
                          color: AppColors.primary,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              club.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (club.isOfficial == true || club.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                club.isVerified ? 'Verificado' : 'Oficial',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        club.teamName,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (club.city != null && club.state != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${club.city}, ${club.state}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          if (club.foundedYear != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Desde ${club.foundedYear}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (club.description != null && club.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                club.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: modeInfo['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: modeInfo['color'].withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    modeInfo['icon'] as IconData,
                    size: 12,
                    color: modeInfo['color'] as Color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    modeInfo['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: modeInfo['color'] as Color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(club),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getJoinModeLabel(FanClub club) {
    if (club.isPublic != true) {
      return {
        'label': 'Privada',
        'icon': Icons.lock,
        'color': AppColors.warning,
      };
    }
    switch (club.joinMode) {
      case 'open':
        return {
          'label': 'Aberta',
          'icon': Icons.public,
          'color': AppColors.success,
        };
      case 'request':
        return {
          'label': 'Solicitar',
          'icon': Icons.person_add,
          'color': AppColors.hubBlue,
        };
      case 'invite_only':
      default:
        return {
          'label': 'Convite',
          'icon': Icons.confirmation_number,
          'color': AppColors.primary,
        };
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.search,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.trim().isNotEmpty
                  ? 'Nenhum resultado encontrado'
                  : 'Busque por torcidas ou times',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.trim().isNotEmpty
                  ? 'Tente buscar por outro time ou cidade.'
                  : 'Digite o nome do time, torcida ou cidade para encontrar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EntrarTorcidaScreen()),
                );
              },
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Tenho um código de convite'),
            ),
          ],
        ),
      ),
    );
  }
}

