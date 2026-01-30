import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/album_service.dart';
import '../constants/app_colors.dart';

class AlbumPhoto {
  final String id;
  final String albumId;
  final String imageUrl;
  final String? caption;
  final String uploadedBy;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;

  AlbumPhoto({
    required this.id,
    required this.albumId,
    required this.imageUrl,
    this.caption,
    required this.uploadedBy,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) {
    return AlbumPhoto(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      imageUrl: json['image_url'] as String,
      caption: json['caption'] as String?,
      uploadedBy: json['uploaded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  final bool canUploadPhotos;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    this.canUploadPhotos = false,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final _authService = AuthServiceSupabase();
  List<AlbumPhoto> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseService.client
          .from('album_photos')
          .select('*')
          .eq('album_id', widget.album.id)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      if (response != null) {
        final List<dynamic> data = response as List;
        final photoIds = data.map((p) => (p as Map)['id'] as String).toList();

        // Buscar likes e comentários
        final likesResponse = await SupabaseService.client
            .from('album_photo_likes')
            .select('photo_id')
            .inFilter('photo_id', photoIds);

        final commentsResponse = await SupabaseService.client
            .from('album_photo_comments')
            .select('photo_id')
            .inFilter('photo_id', photoIds);

        final likesMap = <String, int>{};
        final commentsMap = <String, int>{};

        if (likesResponse != null) {
          for (var like in likesResponse as List) {
            final photoId = (like as Map)['photo_id'] as String;
            likesMap[photoId] = (likesMap[photoId] ?? 0) + 1;
          }
        }

        if (commentsResponse != null) {
          for (var comment in commentsResponse as List) {
            final photoId = (comment as Map)['photo_id'] as String;
            commentsMap[photoId] = (commentsMap[photoId] ?? 0) + 1;
          }
        }

        final photos = data.map((item) {
          final photoData = Map<String, dynamic>.from(item);
          final photoId = photoData['id'] as String;
          return AlbumPhoto(
            id: photoId,
            albumId: photoData['album_id'] as String,
            imageUrl: photoData['image_url'] as String,
            caption: photoData['caption'] as String?,
            uploadedBy: photoData['uploaded_by'] as String,
            createdAt: DateTime.parse(photoData['created_at'] as String),
            likesCount: likesMap[photoId] ?? 0,
            commentsCount: commentsMap[photoId] ?? 0,
          );
        }).toList();

        setState(() {
          _photos = photos;
        });
      }
    } catch (e) {
      print('Erro ao carregar fotos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fotos: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadPhotos(List<File> files) async {
    setState(() {
      _isUploading = true;
    });

    try {
      for (var file in files) {
        // Validar tamanho (10MB)
        if (file.lengthSync() > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arquivo muito grande. Tamanho máximo: 10MB'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          continue;
        }

        final fileExt = file.path.split('.').last;
        final fileName =
            '${widget.album.fanClubId}/albums/${widget.album.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        final fileBytes = await file.readAsBytes();

        await SupabaseService.client.storage
            .from('fan-club-assets')
            .uploadBinary(fileName, fileBytes);

        final urlData = SupabaseService.client.storage
            .from('fan-club-assets')
            .getPublicUrl(fileName);

        await SupabaseService.client.from('album_photos').insert({
          'album_id': widget.album.id,
          'image_url': urlData,
          'uploaded_by': _authService.userId,
          'display_order': _photos.length,
        });
      }

      await _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotos adicionadas com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer upload: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      final files = pickedFiles.map((f) => File(f.path)).toList();
      await _uploadPhotos(files);
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente excluir esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('album_photos')
            .delete()
            .eq('id', photoId);

        await _loadPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto removida'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showPhotoViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PhotoViewerPage(
          photos: _photos,
          initialIndex: index,
          onDelete: widget.canUploadPhotos ? _deletePhoto : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.album.title, style: TextStyle(fontSize: 18),),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : Column(
              children: [
                // Header do álbum
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.album.coverPhotoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.album.coverPhotoUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        widget.album.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.album.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.album.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${_photos.length} ${_photos.length == 1 ? 'foto' : 'fotos'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Grid de fotos
                Expanded(
                  child: _photos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma foto ainda',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            return GestureDetector(
                              onTap: () => _showPhotoViewer(index),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: photo.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                  if (photo.likesCount > 0 ||
                                      photo.commentsCount > 0)
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (photo.likesCount > 0) ...[
                                              const Icon(
                                                Icons.favorite,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${photo.likesCount}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                            if (photo.likesCount > 0 &&
                                                photo.commentsCount > 0)
                                              const SizedBox(width: 8),
                                            if (photo.commentsCount > 0) ...[
                                              const Icon(
                                                Icons.comment,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${photo.commentsCount}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: widget.canUploadPhotos
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _pickPhotos,
              backgroundColor: AppColors.primary,
              child: _isUploading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Icon(Icons.add_photo_alternate, color: Colors.white),
            )
          : null,
    );
  }
}

class _PhotoViewerPage extends StatelessWidget {
  final List<AlbumPhoto> photos;
  final int initialIndex;
  final Future<void> Function(String)? onDelete;

  const _PhotoViewerPage({
    required this.photos,
    required this.initialIndex,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: onDelete != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await onDelete!(photos[initialIndex].id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ]
            : null,
      ),
      body: PageView(
        controller: PageController(initialPage: initialIndex),
        children: photos.map((photo) {
          return Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photo.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

