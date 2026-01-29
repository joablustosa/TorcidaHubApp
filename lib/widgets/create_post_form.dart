import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../services/supabase_service.dart';
import '../services/post_service.dart';
import '../models/supabase_models.dart';

class CreatePostForm extends StatefulWidget {
  final String fanClubId;
  final String userId;
  final Function(Post)? onPostCreated;

  const CreatePostForm({
    super.key,
    required this.fanClubId,
    required this.userId,
    this.onPostCreated,
  });

  @override
  State<CreatePostForm> createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<CreatePostForm> {
  final _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _allowComments = true;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = '${widget.fanClubId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final fileBytes = await _selectedImage!.readAsBytes();
      
      await SupabaseService.client.storage
          .from('fan-club-assets')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = SupabaseService.client.storage
          .from('fan-club-assets')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Erro ao fazer upload da imagem: $e');
      rethrow;
    }
  }

  Future<void> _handleSubmit() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escreva algo ou adicione uma foto para publicar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      final post = await PostService.createPost(
        fanClubId: widget.fanClubId,
        userId: widget.userId,
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        imageUrls: imageUrl != null ? [imageUrl] : null,
      );

      // Limpar formulário
      _contentController.clear();
      setState(() {
        _selectedImage = null;
        _allowComments = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publicação criada!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onPostCreated?.call(post);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar publicação: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campo de texto
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'O que você quer compartilhar com a torcida?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),

            // Preview da imagem
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Ações
            Row(
              children: [
                // Adicionar foto
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate),
                  onPressed: _pickImage,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                // Comentários
                Row(
                  children: [
                    Switch(
                      value: _allowComments,
                      onChanged: (value) {
                        setState(() {
                          _allowComments = value;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    const Text('Comentários'),
                  ],
                ),
                const Spacer(),
                // Botão publicar
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Publicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

