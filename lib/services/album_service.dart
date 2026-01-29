import '../services/supabase_service.dart';

class Album {
  final String id;
  final String fanClubId;
  final String title;
  final String? description;
  final String? coverPhotoUrl;
  final String? eventId;
  final String createdBy;
  final DateTime createdAt;
  final int photoCount;

  Album({
    required this.id,
    required this.fanClubId,
    required this.title,
    this.description,
    this.coverPhotoUrl,
    this.eventId,
    required this.createdBy,
    required this.createdAt,
    this.photoCount = 0,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      fanClubId: json['fan_club_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      eventId: json['event_id'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photoCount: json['photo_count'] as int? ?? 0,
    );
  }
}

class AlbumPhoto {
  final String id;
  final String albumId;
  final String photoUrl;
  final String? caption;
  final String uploadedBy;
  final DateTime createdAt;

  AlbumPhoto({
    required this.id,
    required this.albumId,
    required this.photoUrl,
    this.caption,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) {
    return AlbumPhoto(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      uploadedBy: json['uploaded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AlbumService {
  static Future<List<Album>> getAlbums(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('photo_albums')
          .select()
          .eq('fan_club_id', fanClubId)
          .order('created_at', ascending: false);

      final List<dynamic> data = (response as List? ?? []);
      List<Album> albums = [];

      for (var item in data) {
        final albumData = Map<String, dynamic>.from(item);
        
        // Buscar contagem de fotos
        try {
          final photosResponse = await SupabaseService.client
              .from('album_photos')
              .select('id')
              .eq('album_id', albumData['id'].toString());
          
          albumData['photo_count'] = ((photosResponse as List? ?? []) as List).length;
        } catch (e) {
          print('Erro ao contar fotos: $e');
        }

        albums.add(Album.fromJson(albumData));
      }

      return albums;
    } catch (e) {
      print('Erro ao buscar álbuns: $e');
      return [];
    }
  }

  static Future<Album> createAlbum({
    required String fanClubId,
    required String userId,
    required String title,
    String? description,
    String? eventId,
  }) async {
    try {
      final albumData = {
        'fan_club_id': fanClubId,
        'title': title,
        'description': description,
        'event_id': eventId,
        'created_by': userId,
      };

      final response = await SupabaseService.client
          .from('photo_albums')
          .insert(albumData)
          .select()
          .single();

      return Album.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao criar álbum: $e');
      rethrow;
    }
  }

  static Future<List<AlbumPhoto>> getAlbumPhotos(String albumId) async {
    try {
      final response = await SupabaseService.client
          .from('album_photos')
          .select()
          .eq('album_id', albumId)
          .order('created_at', ascending: false);

      return (response as List? ?? [])
          .map((item) => AlbumPhoto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('Erro ao buscar fotos: $e');
      return [];
    }
  }

  static Future<AlbumPhoto> addPhotoToAlbum({
    required String albumId,
    required String userId,
    required String photoUrl,
    String? caption,
  }) async {
    try {
      final photoData = {
        'album_id': albumId,
        'photo_url': photoUrl,
        'caption': caption,
        'uploaded_by': userId,
      };

      final response = await SupabaseService.client
          .from('album_photos')
          .insert(photoData)
          .select()
          .single();

      return AlbumPhoto.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao adicionar foto: $e');
      rethrow;
    }
  }
}

