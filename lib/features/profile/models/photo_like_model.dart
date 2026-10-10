// lib/features/profile/models/photo_like_model.dart

class PhotoLike {
  final String id;
  final String photoId;
  final String userId;
  final DateTime createdAt;

  PhotoLike({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PhotoLike.fromMap(Map<String, dynamic> map, String id) {
    return PhotoLike(
      id: id,
      photoId: map['photo_id'] ?? '',
      userId: map['user_id']?.toString() ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
