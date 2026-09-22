class Task {
  String id;
  String userId;
  String title;
  String description;
  List<String> subTasks;
  List<String> completedSubTasks;
  DateTime? dueDate;
  bool isCompleted;
  int xpReward;
  DateTime createdAt;
  DateTime updatedAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.subTasks = const [],
    this.completedSubTasks = const [],
    this.dueDate,
    this.isCompleted = false,
    this.xpReward = 10,
    required this.createdAt,
    required this.updatedAt,
  });

  // بررسی آیا تسک برای امروز است
  bool isForToday() {
    return isForDate(DateTime.now());
  }

  // بررسی آیا تسک برای تاریخ مشخص شده است
  bool isForDate(DateTime date) {
    if (dueDate == null) return false;
    // ✅ فقط تاریخ را مقایسه کن (بدون ساعت)
    return dueDate!.year == date.year &&
        dueDate!.month == date.month &&
        dueDate!.day == date.day;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'sub_tasks': subTasks,
      'completed_sub_tasks': completedSubTasks,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
      'xp_reward': xpReward,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // lib/features/arena/models/task_model.dart

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        print('⚠️ Error parsing date: $dateStr');
        return DateTime.now();
      }
    }

    return Task(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subTasks: List<String>.from(map['subTasks'] ?? []),
      completedSubTasks: List<String>.from(map['completedSubTasks'] ?? []),
      dueDate: map['dueDate'] != null ? parseDate(map['dueDate']) : null,
      isCompleted: map['isCompleted'] ?? false,
      xpReward: map['xpReward'] ?? 10,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
  int get completedCount => completedSubTasks.length;

  double get progressPercent =>
      subTasks.isEmpty ? 0 : completedCount / subTasks.length;
}
