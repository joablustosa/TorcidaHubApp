import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../constants/app_colors.dart';
import '../models/supabase_models.dart';

class CreateAlbumDialog extends StatefulWidget {
  final String fanClubId;
  final List<Event> events;
  final VoidCallback? onAlbumCreated;

  const CreateAlbumDialog({
    super.key,
    required this.fanClubId,
    this.events = const [],
    this.onAlbumCreated,
  });

  @override
  State<CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<CreateAlbumDialog> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthServiceSupabase();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _coverFile;
  String? _coverPreview;
  String? _selectedEventId;
  bool _isLoading = false;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Validar tamanho (10MB)
      if (file.lengthSync() > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O arquivo é muito grande. Tamanho máximo: 10MB'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _isAnalyzing = true;
      });

      // TODO: Implementar NSFW detection
      // Por enquanto, apenas aceitar a imagem
      
      setState(() {
        _coverFile = file;
        _coverPreview = file.path;
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? coverUrl;

      if (_coverFile != null) {
        final fileExt = _coverFile!.path.split('.').last;
        final fileName = '${widget.fanClubId}/albums/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        final fileBytes = await _coverFile!.readAsBytes();
        
        await SupabaseService.client.storage
            .from('fan-club-assets')
            .uploadBinary(fileName, fileBytes);

        final urlData = SupabaseService.client.storage
            .from('fan-club-assets')
            .getPublicUrl(fileName);

        coverUrl = urlData;
      }

      await SupabaseService.client.from('photo_albums').insert({
        'fan_club_id': widget.fanClubId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'event_id': _selectedEventId?.isEmpty ?? true ? null : _selectedEventId,
        'cover_photo_url': coverUrl,
        'created_by': _authService.userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Álbum criado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
        widget.onAlbumCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar álbum: ${e.toString()}'),
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
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Criar Novo Álbum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          hintText: 'Nome do álbum',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Descrição
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'Descrição do álbum (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // Evento relacionado
                      if (widget.events.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: _selectedEventId,
                          decoration: const InputDecoration(
                            labelText: 'Evento Relacionado',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Selecione um evento (opcional)'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Nenhum evento'),
                            ),
                            ...widget.events.map((event) {
                              return DropdownMenuItem<String>(
                                value: event.id,
                                child: Text(event.title),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedEventId = value;
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                      // Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Apenas você (criador do álbum) poderá adicionar fotos a este álbum.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Capa do álbum
                      const Text(
                        'Capa do Álbum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Preview
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.textSecondary.withOpacity(0.2),
                              ),
                            ),
                            child: _isAnalyzing
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : _coverPreview != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_coverPreview!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_photo_alternate,
                                        size: 32,
                                        color: AppColors.textSecondary,
                                      ),
                          ),
                          const SizedBox(width: 16),
                          // Botão
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isAnalyzing ? null : _pickCoverImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Selecionar Imagem'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Criar Álbum'),
                            ),
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
      ),
    );
  }
}

