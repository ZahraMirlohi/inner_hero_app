class UserPackage {
  final String id;
  final String userId;
  final String packageId;
  final bool isActive;
  final DateTime addedAt;
  final DateTime? removedAt;

  UserPackage({
    required this.id,
    required this.userId,
    required this.packageId,
    this.isActive = true,
    required this.addedAt,
    this.removedAt,
  });

  factory UserPackage.fromMap(Map<String, dynamic> map, String id) {
    return UserPackage(
      id: id,
      userId: map['user_id'] ?? '',
      packageId: map['package_id'] ?? '',
      isActive: map['is_active'] ?? true,
      addedAt: DateTime.parse(
        map['added_at'] ?? DateTime.now().toIso8601String(),
      ),
      removedAt: map['removed_at'] != null
          ? DateTime.parse(map['removed_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'package_id': packageId,
      'is_active': isActive,
      'added_at': addedAt.toIso8601String(),
      'removed_at': removedAt?.toIso8601String(),
    };
  }
}
