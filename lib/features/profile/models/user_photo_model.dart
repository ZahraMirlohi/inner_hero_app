// lib/features/profile/models/user_photo_model.dart

class UserPhoto {
  final String id;
  final String userId;
  final String photoUrl;
  final String storagePath;
  final String? caption;
  final int? fileSize;
  final int? width;
  final int? height;
  final bool isPrimary;
  final int displayOrder;
  final int likesCount;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPhoto({
    required this.id,
    required this.userId,
    required this.photoUrl,
    required this.storagePath,
    this.caption,
    this.fileSize,
    this.width,
    this.height,
    this.isPrimary = false,
    this.displayOrder = 0,
    this.likesCount = 0,
    this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'photo_url': photoUrl,
      'storage_path': storagePath,
      'caption': caption,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'is_primary': isPrimary,
      'display_order': displayOrder,
      'likes_count': likesCount,
      'is_visible': isVisible,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserPhoto.fromMap(Map<String, dynamic> map, String id) {
    return UserPhoto(
      id: id,
      userId: map['user_id']?.toString() ?? '',
      photoUrl: map['photo_url'] ?? '',
      storagePath: map['storage_path'] ?? '',
      caption: map['caption'],
      fileSize: map['file_size'],
      width: map['width'],
      height: map['height'],
      isPrimary: map['is_primary'] ?? false,
      displayOrder: map['display_order'] ?? 0,
      likesCount: map['likes_count'] ?? 0,
      isVisible: map['is_visible'] ?? true,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  UserPhoto copyWith({
    String? photoUrl,
    String? storagePath,
    String? caption,
    bool? isPrimary,
    int? displayOrder,
    int? likesCount,
    bool? isVisible,
  }) {
    return UserPhoto(
      id: id,
      userId: userId,
      photoUrl: photoUrl ?? this.photoUrl,
      storagePath: storagePath ?? this.storagePath,
      caption: caption ?? this.caption,
      fileSize: fileSize,
      width: width,
      height: height,
      isPrimary: isPrimary ?? this.isPrimary,
      displayOrder: displayOrder ?? this.displayOrder,
      likesCount: likesCount ?? this.likesCount,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
