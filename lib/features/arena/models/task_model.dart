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
    return dueDate!.year == date.year &&
        dueDate!.month == date.month &&
        dueDate!.day == date.day;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'subTasks': subTasks,
      'completedSubTasks': completedSubTasks,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'xpReward': xpReward,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subTasks: List<String>.from(map['subTasks'] ?? []),
      completedSubTasks: List<String>.from(map['completedSubTasks'] ?? []),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      isCompleted: map['isCompleted'] ?? false,
      xpReward: map['xpReward'] ?? 10,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  int get completedCount => completedSubTasks.length;

  double get progressPercent =>
      subTasks.isEmpty ? 0 : completedCount / subTasks.length;
}
