import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../data/brazilian_cities.dart';
import '../widgets/torcida_hub_bottom_nav.dart';
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
  final _descriptionController = TextEditingController();
  final _authService = AuthServiceSupabase();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isPublic = false;
  String _selectedState = '';
  String _selectedCity = '';
  String _selectedSport = 'football';
  File? _logoFile;
  File? _coverFile;

  final List<Map<String, String>> _sports = [
    {'value': 'football', 'label': 'Futebol'},
    {'value': 'basketball', 'label': 'Basquete'},
    {'value': 'volleyball', 'label': 'Vôlei'},
    {'value': 'motorsport', 'label': 'Automobilismo'},
    {'value': 'mma', 'label': 'MMA / Lutas'},
    {'value': 'esports', 'label': 'eSports'},
    {'value': 'other', 'label': 'Outro'},
  ];

  List<String> get _cities => BrazilianCities.getCitiesForState(_selectedState);

  Future<void> _pickImage(bool isCover) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        if (isCover) {
          _coverFile = File(picked.path);
        } else {
          _logoFile = File(picked.path);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _uploadFile(File file, String prefix) async {
    if (_authService.userId == null) return null;
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final fileName =
          'temp/${_authService.userId}/$prefix-${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final fileBytes = await file.readAsBytes();

      await SupabaseService.client.storage
          .from('fan-club-assets')
          .uploadBinary(fileName, fileBytes);

      return SupabaseService.client.storage
          .from('fan-club-assets')
          .getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_authService.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para criar uma torcida'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o estado'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a cidade'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? logoUrl;
      String? coverUrl;

      if (_logoFile != null) {
        logoUrl = await _uploadFile(_logoFile!, 'logo');
      }
      if (_coverFile != null) {
        coverUrl = await _uploadFile(_coverFile!, 'cover');
      }

      final fanClubData = {
        'name': _nameController.text.trim(),
        'team_name': _teamNameController.text.trim(),
        'city': _selectedCity,
        'state': _selectedState,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'logo_url': logoUrl,
        'cover_url': coverUrl,
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

      await SupabaseService.client.from('fan_club_members').insert({
        'fan_club_id': fanClub.id,
        'user_id': _authService.userId,
        'position': 'presidente',
        'status': 'active',
        'badge_level': 'bronze',
        'registration_number':
            '00001-${DateTime.now().year.toString().substring(2)}',
        'points': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Torcida criada com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
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
        final msg = e.toString();
        String userMsg = 'Erro ao criar torcida. Tente novamente.';
        if (msg.contains('duplicate') || msg.contains('23505')) {
          userMsg = 'Já existe uma torcida com dados semelhantes.';
        } else if (msg.contains('RLS') || msg.contains('policy')) {
          userMsg = 'Sem permissão para criar torcida. Verifique sua conta.';
        } else if (msg.isNotEmpty) {
          userMsg = msg.length > 80 ? '${msg.substring(0, 80)}...' : msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Criar Nova Torcida', style: TextStyle(fontSize: 18),),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo e Capa
              Row(
                children: [
                  Expanded(
                    child: _buildImageBlock(
                      label: 'Logo',
                      file: _logoFile,
                      onTap: () => _pickImage(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildImageBlock(
                      label: 'Capa',
                      file: _coverFile,
                      onTap: () => _pickImage(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('Identidade da torcida'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Nome da Torcida *', hint: 'Ex: Gaviões da Fiel'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Insira o nome da torcida' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedSport,
                decoration: _inputDecoration('Esporte *'),
                items: _sports
                    .map((s) => DropdownMenuItem(
                          value: s['value'],
                          child: Text(s['label']!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSport = v ?? 'football'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _teamNameController,
                decoration: _inputDecoration('Time que Torce *', hint: 'Ex: Corinthians'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Insira o nome do time' : null,
              ),
              const SizedBox(height: 24),

              _sectionTitle('Localização'),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedState.isEmpty ? null : _selectedState,
                decoration: _inputDecoration('Estado *'),
                items: BrazilianCities.states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedState = v ?? '';
                    _selectedCity = '';
                  });
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Selecione o estado' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCity.isEmpty ? null : _selectedCity,
                decoration: InputDecoration(
                  labelText: 'Cidade *',
                  hintText: _selectedState.isEmpty
                      ? 'Selecione o estado primeiro'
                      : _cities.isEmpty
                          ? 'Nenhuma cidade'
                          : 'Selecione a cidade',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _cities.isEmpty
                    ? null
                    : (v) => setState(() => _selectedCity = v ?? ''),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Selecione a cidade' : null,
              ),
              const SizedBox(height: 24),

              _sectionTitle('Descrição'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _inputDecoration(
                  'Descrição (opcional)',
                  hint: 'Conte um pouco sobre a história e missão da torcida...',
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.12),
                  ),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Torcida Pública',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Qualquer pessoa pode encontrar e entrar.'
                        : 'Apenas com código de convite.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textLight,
                          ),
                        ),
                      )
                    : const Text(
                        'Criar torcida',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TorcidaHubBottomNav(
        currentIndex: 2,
        onTap: (index) => TorcidaHubBottomNav.navigateTo(context, index, 2),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            title.contains('Identidade')
                ? Icons.groups_rounded
                : title.contains('Localização')
                    ? Icons.location_on_rounded
                    : Icons.description_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildImageBlock({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.15),
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    label == 'Logo'
                        ? Icons.add_photo_alternate_rounded
                        : Icons.photo_library_rounded,
                    size: 32,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
