import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'minha_torcida_screen.dart';
import 'auth/login_screen.dart';

class EntrarTorcidaScreen extends StatefulWidget {
  const EntrarTorcidaScreen({super.key});

  @override
  State<EntrarTorcidaScreen> createState() => _EntrarTorcidaScreenState();
}

class _EntrarTorcidaScreenState extends State<EntrarTorcidaScreen> {
  final _authService = AuthServiceSupabase();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSearch() async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.isEmpty || code.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o código do convite'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_authService.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para entrar na torcida'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Buscar convite
      final inviteResponse = await SupabaseService.client
          .from('fan_club_invites')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (inviteResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código de convite inválido ou expirado'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final inviteData = Map<String, dynamic>.from(inviteResponse);

      // Verificar se expirou
      if (inviteData['expires_at'] != null) {
        final expiresAt = DateTime.parse(inviteData['expires_at'] as String);
        if (expiresAt.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este convite expirou'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Verificar limite de usos
      if (inviteData['max_uses'] != null) {
        final maxUses = inviteData['max_uses'] as int;
        final usesCount = inviteData['uses_count'] as int? ?? 0;
        if (usesCount >= maxUses) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este convite atingiu o limite de usos'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Buscar torcida
      final fanClubResponse = await SupabaseService.client
          .from('fan_clubs')
          .select()
          .eq('id', inviteData['fan_club_id'] as String)
          .maybeSingle();

      if (fanClubResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Torcida não encontrada'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final fanClub = FanClub.fromJson(Map<String, dynamic>.from(fanClubResponse));

      // Verificar se já é membro
      final existingMemberResponse = await SupabaseService.client
          .from('fan_club_members')
          .select('id')
          .eq('fan_club_id', fanClub.id)
          .eq('user_id', _authService.userId!)
          .maybeSingle();

      if (existingMemberResponse != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já é membro desta torcida!'),
            backgroundColor: AppColors.info,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MinhaTorcidaScreen(fanClubId: fanClub.id),
          ),
        );
        return;
      }

      // Gerar número de registro
      final regNumberResponse = await SupabaseService.client
          .rpc('generate_registration_number', params: {'_fan_club_id': fanClub.id});

      String regNumber = '00001-${DateTime.now().year.toString().substring(2)}';
      if (regNumberResponse != null) {
        if (regNumberResponse is String) {
          regNumber = regNumberResponse;
        } else if (regNumberResponse is Map && regNumberResponse['data'] != null) {
          regNumber = regNumberResponse['data'].toString();
        }
      }

      // Adicionar como membro
      await SupabaseService.client.from('fan_club_members').insert({
        'fan_club_id': fanClub.id,
        'user_id': _authService.userId,
        'position': 'membro',
        'status': 'active',
        'registration_number': regNumber,
        'badge_level': 'bronze',
        'points': 0,
      });

      // Atualizar contagem de usos do convite
      final currentUses = inviteData['uses_count'] as int? ?? 0;
      await SupabaseService.client
          .from('fan_club_invites')
          .update({'uses_count': currentUses + 1})
          .eq('id', inviteData['id'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você entrou na torcida ${fanClub.name} com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MinhaTorcidaScreen(fanClubId: fanClub.id),
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
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
        title: const Text('Entrar em uma Torcida'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.confirmation_number,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Código de Convite',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite o código de 8 caracteres que você recebeu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          maxLength: 8,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'ABC12345',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          onSubmitted: (_) => _handleSearch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading || _codeController.text.length < 8
                            ? null
                            : _handleSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textLight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Buscar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

