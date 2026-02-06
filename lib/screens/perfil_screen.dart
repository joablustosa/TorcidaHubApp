import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../models/supabase_models.dart';
import '../constants/app_colors.dart';
import '../widgets/torcida_hub_bottom_nav.dart';
import 'auth/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _authService = AuthServiceSupabase();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _cpfController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  Profile? _profile;
  File? _selectedAvatar;
  String? _avatarUrl;
  String _selectedState = '';

  final List<String> _states = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', _authService.userId!)
          .maybeSingle();

      if (response != null) {
        final profile = Profile.fromJson(Map<String, dynamic>.from(response));
        setState(() {
          _profile = profile;
          _nameController.text = profile.fullName ?? '';
          _nicknameController.text = profile.nickname ?? '';
          _phoneController.text = '';
          _cityController.text = '';
          _cpfController.text = '';
          _selectedState = '';
          _avatarUrl = profile.avatarUrl;
        });
      }
    } catch (e) {
      print('Erro ao carregar perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedAvatar = File(image.path);
        });
        await _uploadAvatar();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedAvatar == null || _authService.userId == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final fileName = '${_authService.userId}/avatar.jpg';
      final fileBytes = await _selectedAvatar!.readAsBytes();

      // Deletar avatar antigo se existir
      try {
        await SupabaseService.client.storage
            .from('fan-club-assets')
            .remove([fileName]);
      } catch (e) {
        // Ignorar erro se arquivo não existir
      }

      await SupabaseService.client.storage
          .from('fan-club-assets')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = SupabaseService.client.storage
          .from('fan-club-assets')
          .getPublicUrl(fileName);

      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', _authService.userId!);

      setState(() {
        _avatarUrl = publicUrl;
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProfile();
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'full_name': _nameController.text.trim(),
            'nickname': _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'city': _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            'state': _selectedState.isEmpty ? null : _selectedState,
            'cpf': _cpfController.text.trim().isEmpty
                ? null
                : _cpfController.text.trim().replaceAll(RegExp(r'\D'), ''),
          })
          .eq('id', _authService.userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _cpfController.dispose();
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Meu Perfil', style: TextStyle(fontSize: 18),),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar – estilo dashboard
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: _avatarUrl != null
                        ? CachedNetworkImageProvider(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: _isUploadingAvatar
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
                            : const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _isUploadingAvatar ? null : _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email
              Text(
                _authService.userEmail ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_profile?.nickname != null) ...[
                const SizedBox(height: 4),
                Text(
                  '@${_profile!.nickname}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Formulário – estilo dashboard
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome Completo *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome completo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: 'Apelido',
                  hintText: 'Como você quer ser chamado',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefone',
                  hintText: '(11) 99999-9999',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'CPF',
                  hintText: '000.000.000-00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedState.isEmpty ? null : _selectedState,
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Botão Salvar – estilo dashboard
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Salvar alterações',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Botão Sair
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                  ),
                  child: const Text('Sair'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TorcidaHubBottomNav(
        currentIndex: 0,
        onTap: (index) => TorcidaHubBottomNav.navigateTo(context, index, 0),
      ),
    );
  }
}
