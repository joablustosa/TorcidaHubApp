import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import 'minha_torcida_screen.dart';

class CriarTorcidaScreen extends StatefulWidget {
  const CriarTorcidaScreen({super.key});

  @override
  State<CriarTorcidaScreen> createState() => _CriarTorcidaScreenState();
}

class _CriarTorcidaScreenState extends State<CriarTorcidaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authService = AuthServiceSupabase();
  
  bool _isLoading = false;
  bool _isPublic = false;
  String _selectedState = '';
  String _selectedSport = 'football';
  String? _logoUrl;

  final List<String> _states = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];

  final List<Map<String, String>> _sports = [
    {'value': 'football', 'label': 'Futebol'},
    {'value': 'basketball', 'label': 'Basquete'},
    {'value': 'volleyball', 'label': 'Vôlei'},
    {'value': 'motorsport', 'label': 'Automobilismo'},
    {'value': 'mma', 'label': 'MMA / Lutas'},
    {'value': 'esports', 'label': 'eSports'},
    {'value': 'other', 'label': 'Outro'},
  ];

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_authService.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para criar uma torcida'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Criar torcida
      final fanClubData = {
        'name': _nameController.text.trim(),
        'team_name': _teamNameController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _selectedState,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'logo_url': _logoUrl,
        'created_by': _authService.userId,
        'is_public': _isPublic,
        'sport_type': _selectedSport,
        'is_official': false,
        'is_verified': false,
        'join_mode': _isPublic ? 'public' : 'invite_only',
      };

      final response = await SupabaseService.client
          .from('fan_clubs')
          .insert(fanClubData)
          .select()
          .single();

      final fanClub = FanClub.fromJson(response as Map<String, dynamic>);

      // Adicionar criador como presidente
      await SupabaseService.client.from('fan_club_members').insert({
        'fan_club_id': fanClub.id,
        'user_id': _authService.userId,
        'position': 'presidente',
        'status': 'active',
        'badge_level': 'bronze',
        'registration_number': '00001-${DateTime.now().year.toString().substring(2)}',
        'points': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Torcida criada com sucesso!'),
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
            content: Text('Erro ao criar torcida: ${e.toString()}'),
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
    _nameController.dispose();
    _teamNameController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Criar Nova Torcida'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo upload placeholder
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Logo da Torcida',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nome da Torcida
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da Torcida *',
                  hintText: 'Ex: Gaviões da Fiel',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome da torcida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Esporte
              DropdownButtonFormField<String>(
                value: _selectedSport,
                decoration: InputDecoration(
                  labelText: 'Esporte *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                items: _sports.map((sport) {
                  return DropdownMenuItem(
                    value: sport['value'],
                    child: Text(sport['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSport = value ?? 'football';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Time que Torce
              TextFormField(
                controller: _teamNameController,
                decoration: InputDecoration(
                  labelText: 'Time que Torce *',
                  hintText: 'Ex: Corinthians',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome do time';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cidade e Estado
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Cidade *',
                        hintText: 'Ex: São Paulo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedState.isEmpty ? null : _selectedState,
                      decoration: InputDecoration(
                        labelText: 'Estado *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      items: _states.map((state) {
                        return DropdownMenuItem(
                          value: state,
                          child: Text(state),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descrição
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Conte um pouco sobre a história e missão da sua torcida...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 24),

              // Torcida Pública/Privada
              Card(
                child: SwitchListTile(
                  title: const Text('Torcida Pública'),
                  subtitle: Text(
                    _isPublic
                        ? 'Qualquer pessoa poderá encontrar e entrar na torcida sem convite.'
                        : 'Apenas pessoas com código de convite poderão entrar na torcida.',
                  ),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Botão Criar
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                            AppColors.textLight,
                          ),
                        ),
                      )
                    : const Text(
                        'CRIAR TORCIDA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

