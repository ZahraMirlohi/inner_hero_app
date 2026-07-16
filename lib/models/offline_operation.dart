// lib/models/offline_operation.dart

enum OperationType {
  createHabit,
  updateHabit,
  deleteHabit,
  createTask,
  updateTask,
  deleteTask,
  completeHabit,
  uncompleteHabit,
  completeTask,
  uncompleteTask,
  createProfile,
  updateProfile,
}

class OfflineOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String userId;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  factory OfflineOperation.fromMap(Map<String, dynamic> map) {
    return OfflineOperation(
      id: map['id'] as String,
      type: OperationType.values[map['type'] as int],
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
      userId: map['userId'] as String,
    );
  }

  @override
  String toString() {
    return 'OfflineOperation(id: $id, type: $type, userId: $userId, timestamp: $timestamp)';
  }
}
