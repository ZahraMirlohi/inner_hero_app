import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import '/features/arena/models/habit_model.dart';
import '/features/arena/models/task_model.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  late Client client;
  late Account account;
  late Databases databases;
  late Realtime realtime;

  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '6a25e1ce002d7cc4bc2e';
  static const String databaseId = '6a27134f000c2f9407f0';
  static const String habitsCollectionId = 'habits';
  static const String tasksCollectionId = 'tasks';
  static const String userProgressCollectionId = 'user_progress';
  static const String habitCompletionsCollectionId = 'habit_completions';

  Future<void> init() async {
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setSelfSigned(status: true);
    account = Account(client);
    databases = Databases(client);
    realtime = Realtime(client);
  }

  // ==================== Auth ====================

  Future<models.User> login(String email, String password) async {
    try {
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return await account.get();
    } catch (e) {
      rethrow;
    }
  }

  Future<models.User> signup(String email, String password, String name) async {
    try {
      await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      await login(email, password);
      return await account.get();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await account.deleteSession(sessionId: 'current');
  }

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      return null;
    }
  }

  // ==================== Habits ====================

  Future<List<Habit>> getHabits(String userId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: habitsCollectionId,
        queries: [Query.equal('userId', userId)],
      );
      return result.documents
          .map((doc) => Habit.fromMap(doc.$id, doc.data))
          .toList();
    } catch (e) {
      debugPrint('Error getting habits: $e');
      return [];
    }
  }

  Future<Habit> createHabit(Habit habit) async {
    try {
      final data = habit.toMap();
      data.remove('id');

      final doc = await databases.createDocument(
        databaseId: databaseId,
        collectionId: habitsCollectionId,
        documentId: ID.unique(),
        data: data,
      );
      return Habit.fromMap(doc.$id, doc.data);
    } catch (e) {
      debugPrint('Error creating habit: $e');
      rethrow;
    }
  }

  Future<Habit> updateHabit(Habit habit) async {
    final data = habit.toMap();
    data.remove('id');

    final doc = await databases.updateDocument(
      databaseId: databaseId,
      collectionId: habitsCollectionId,
      documentId: habit.id,
      data: data,
    );
    return Habit.fromMap(doc.$id, doc.data);
  }

  Future<void> deleteHabit(String habitId) async {
    await databases.deleteDocument(
      databaseId: databaseId,
      collectionId: habitsCollectionId,
      documentId: habitId,
    );
  }

  // ==================== Tasks ====================

  Future<List<Task>> getTasks(String userId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        queries: [Query.equal('userId', userId)],
      );
      return result.documents
          .map((doc) => Task.fromMap(doc.$id, doc.data))
          .toList();
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  Future<Task> createTask(Task task) async {
    final data = task.toMap();
    data.remove('id');

    final doc = await databases.createDocument(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
      documentId: ID.unique(),
      data: data,
    );
    return Task.fromMap(doc.$id, doc.data);
  }

  Future<Task> updateTask(Task task) async {
    final data = task.toMap();
    data.remove('id');

    final doc = await databases.updateDocument(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
      documentId: task.id,
      data: data,
    );
    return Task.fromMap(doc.$id, doc.data);
  }

  Future<void> deleteTask(String taskId) async {
    await databases.deleteDocument(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
      documentId: taskId,
    );
  }

  // ==================== Habit Completion ====================

  // appwrite_service.dart

  Future<bool> isHabitCompletedOnDate(
    String habitId,
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: habitCompletionsCollectionId,
        queries: [
          Query.equal('habitId', habitId),
          Query.equal('userId', userId),
          Query.equal('date', dateStr),
        ],
      );

      return result.documents.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking habit completion: $e');
      return false;
    }
  }

  Future<void> markHabitCompletedToday(
    String habitId,
    String userId,
    DateTime date,
    bool completed,
  ) async {
    await markHabitCompletedOnDate(habitId, userId, date, completed);
  }

  // appwrite_service.dart

  Future<void> markHabitCompletedOnDate(
    String habitId,
    String userId,
    DateTime date,
    bool completed,
  ) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // بررسی وجود رکورد قبلی
      final existing = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: habitCompletionsCollectionId,
        queries: [
          Query.equal('habitId', habitId),
          Query.equal('userId', userId),
          Query.equal('date', dateStr),
        ],
      );

      if (existing.documents.isNotEmpty) {
        if (!completed) {
          // حذف رکورد
          await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: habitCompletionsCollectionId,
            documentId: existing.documents.first.$id,
          );
          debugPrint('🗑️ عادت $habitId در تاریخ $dateStr حذف شد');
        } else {
          debugPrint('ℹ️ عادت $habitId قبلاً در تاریخ $dateStr ثبت شده');
        }
      } else if (completed) {
        // ایجاد رکورد جدید
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: habitCompletionsCollectionId,
          documentId: ID.unique(),
          data: {
            'habitId': habitId,
            'userId': userId,
            'date': dateStr,
            'completedAt': DateTime.now().toIso8601String(),
          },
        );
        debugPrint('✅ عادت $habitId در تاریخ $dateStr ثبت شد');
      }
    } catch (e) {
      debugPrint('❌ Error marking habit completion: $e');
    }
  }

  // ==================== XP Management ====================

  Future<void> addXP(String userId, int amount) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: userProgressCollectionId,
        queries: [Query.equal('userId', userId)],
      );

      if (result.documents.isNotEmpty) {
        final doc = result.documents.first;
        int currentXP = doc.data['totalXP'] ?? 0;
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: userProgressCollectionId,
          documentId: doc.$id,
          data: {'totalXP': currentXP + amount},
        );
      } else {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: userProgressCollectionId,
          documentId: ID.unique(),
          data: {'userId': userId, 'totalXP': amount},
        );
      }
    } catch (e) {
      debugPrint('Error adding XP: $e');
    }
  }

  Future<int> getUserXP(String userId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: userProgressCollectionId,
        queries: [Query.equal('userId', userId)],
      );
      if (result.documents.isNotEmpty) {
        return result.documents.first.data['totalXP'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ==================== Explore Section ====================

  // دریافت چالش‌های فعال (که ثبت‌نام در آنها هنوز تمام نشده)
  Future<List<Map<String, dynamic>>> getChallenges() async {
    try {
      final now = DateTime.now().toIso8601String();
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'challenges',
        queries: [
          Query.equal('isActive', true),
          Query.greaterThan(
            'registrationEndDate',
            now,
          ), // فقط چالش‌هایی که ثبت‌نام آنها تمام نشده
        ],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting challenges: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTemplatePackages() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'template_packages',
        queries: [Query.equal('isActive', true)],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getQuests() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'quests',
        queries: [Query.equal('isActive', true)],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCosmetics() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'cosmetics',
        queries: [Query.equal('isActive', true)],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailySpark() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'daily_spark',
        queries: [Query.equal('isActive', true)],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getQuotes() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'quotes',
        queries: [Query.equal('isActive', true)],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // appwrite_service.dart

  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        queries: [Query.equal('userId', userId)],
      );

      List<Map<String, dynamic>> activeChallenges = [];
      final now = DateTime.now();

      for (var doc in result.documents) {
        final challengeId = doc.data['challengeId'];
        if (challengeId == null || challengeId.isEmpty) {
          continue;
        }

        try {
          final challengeDoc = await databases.getDocument(
            databaseId: databaseId,
            collectionId: 'challenges',
            documentId: challengeId,
          );

          final challengeData = challengeDoc.data;
          final startDate = DateTime.parse(challengeData['startDate']);
          final endDate = DateTime.parse(challengeData['endDate']);

          // فقط چالش‌هایی که هنوز تاریخ پایانشون نرسیده رو نشون بده
          if (now.isBefore(endDate)) {
            challengeData['id'] = challengeDoc.$id;
            challengeData['userProgressId'] = doc.$id;
            challengeData['joinedAt'] = doc.data['joinedAt'];
            challengeData['progress'] = doc.data['progress'] ?? 0;
            activeChallenges.add(challengeData);
          } else {
            // اگه چالش تموم شده، می‌تونی یه جایزه یا اخطار بدی
            // و بعداً حذفش کنی
            debugPrint('Challenge ${challengeData['title']} has ended');
          }
        } catch (e) {
          debugPrint('Error getting challenge $challengeId: $e');
          // اگه چالش پیدا نشد، رکورد user_challenge رو پاک کن
          await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: 'user_challenges',
            documentId: doc.$id,
          );
        }
      }
      return activeChallenges;
    } catch (e) {
      debugPrint('Error getting user challenges: $e');
      return [];
    }
  }

  // متد joinChallenge رو ساده‌تر کن (بدون آپدیت participants)
  Future<void> joinChallenge(String userId, String challengeId) async {
    try {
      final existing = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        queries: [
          Query.equal('userId', userId),
          Query.equal('challengeId', challengeId),
        ],
      );

      if (existing.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: 'user_challenges',
          documentId: ID.unique(),
          data: {
            'userId': userId,
            'challengeId': challengeId,
            'progress': 0,
            'isCompleted': false,
            'joinedAt': DateTime.now().toIso8601String(),
            'xpEarned': 0,
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // متد leaveChallenge رو هم ساده‌تر کن
  Future<void> leaveChallenge(
    String userId,
    String challengeId,
    String userProgressId,
  ) async {
    try {
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        documentId: userProgressId,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateLocalChallenges() async {
    final freshChallenges = await getChallenges();
    // به‌روزرسانی لیست محلی در explore_screen
    // این کار در _loadData انجام می‌شود
  }

  // حذف عادت چالش
  Future<void> removeChallengeHabitFromUser(
    String userId,
    String challengeTitle,
  ) async {
    try {
      final habits = await getHabits(userId);
      for (var habit in habits) {
        if (habit.title.contains(challengeTitle) ||
            habit.title.contains(challengeTitle.replaceAll('🏆', '').trim())) {
          await deleteHabit(habit.id);
        }
      }
    } catch (e) {
      debugPrint('Error removing challenge habit: $e');
    }
  }

  // ایجاد گروه چت برای چالش
  Future<void> createChallengeGroup(
    String challengeId,
    String challengeTitle,
  ) async {
    try {
      // در اینجا می‌توانید یک گروه در collection گروه‌ها ایجاد کنید
      // برای نسخه بعدی
      debugPrint('Creating group for challenge: $challengeTitle');
    } catch (e) {
      debugPrint('Error creating group: $e');
    }
  }

  // appwrite_service.dart

  Future<void> addChallengeHabitToUser(
    String userId,
    Map<String, dynamic> challenge,
  ) async {
    try {
      debugPrint('========== شروع اضافه کردن چالش ==========');
      debugPrint('userId: $userId');
      debugPrint('challengeId: ${challenge['id']}');
      debugPrint('challengeTitle: ${challenge['title']}');
      debugPrint('challengeDuration: ${challenge['challengeDuration']}');

      final startDate = DateTime.now();
      final duration = challenge['challengeDuration'] as int;
      // اصلاح: تاریخ پایان = روز شروع + (مدت زمان - 1)
      final endDate = startDate.add(Duration(days: duration - 1));

      debugPrint('تاریخ شروع: $startDate');
      debugPrint('تاریخ پایان: $endDate');
      debugPrint('مدت زمان: $duration روز');

      final xpPerDay = (challenge['xpReward'] as int) ~/ duration;

      List<String> subHabits = [];
      if (challenge['tasks'] != null &&
          challenge['tasks'].toString().isNotEmpty) {
        subHabits = challenge['tasks']
            .toString()
            .split(',')
            .map((t) => t.trim())
            .toList();
        debugPrint('زیرعادت‌ها: $subHabits');
      }

      // ساخت عادت جدید
      final newHabit = Habit(
        id: ID.unique(),
        userId: userId,
        title: '🏆 چالش: ${challenge['title']}',
        description: '${challenge['description']} - ${duration} روز',
        subHabits: subHabits,
        completedSubHabits: [],
        iconName: 'emoji_events',
        iconColor: 0xFFFFA500,
        backgroundColor: 0xFFF5F5F5,
        frequencyType: 'daily',
        startDate: startDate,
        endDate: endDate,
        challengeId: challenge['id'],
        xpReward: xpPerDay > 0 ? xpPerDay : 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('عادت ساخته شد: ${newHabit.title}');
      debugPrint('challengeId در عادت: ${newHabit.challengeId}');
      debugPrint('startDate: ${newHabit.startDate}');
      debugPrint('endDate: ${newHabit.endDate}');

      // ذخیره در دیتابیس
      await createHabit(newHabit);

      debugPrint('✅ عادت با موفقیت در دیتابیس ذخیره شد');
      debugPrint('========== پایان اضافه کردن چالش ==========');
    } catch (e) {
      debugPrint('❌ Error adding challenge habit: $e');
      debugPrint('StackTrace: ${StackTrace.current}');
      rethrow;
    }
  }

  // دریافت تعداد واقعی شرکت‌کنندگان یک چالش
  Future<int> getRealParticipantsCount(String challengeId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        queries: [Query.equal('challengeId', challengeId)],
      );
      return result.total;
    } catch (e) {
      debugPrint('Error getting real participants count: $e');
      return 0;
    }
  }

  // دریافت همه شرکت‌کنندگان یک چالش (برای نمایش لیست)
  Future<List<Map<String, dynamic>>> getChallengeParticipants(
    String challengeId,
  ) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        queries: [Query.equal('challengeId', challengeId)],
      );

      List<Map<String, dynamic>> participants = [];
      for (var doc in result.documents) {
        final userId = doc.data['userId'];
        try {
          final user = await account.get();
          // توجه: اینجا فقط کاربر فعلی رو می‌گیره
          // برای گرفتن همه کاربرا نیاز به collection users داری
          participants.add({
            'userId': userId,
            'joinedAt': doc.data['joinedAt'],
            'progress': doc.data['progress'] ?? 0,
          });
        } catch (e) {
          participants.add({
            'userId': userId,
            'joinedAt': doc.data['joinedAt'],
            'progress': doc.data['progress'] ?? 0,
          });
        }
      }
      return participants;
    } catch (e) {
      debugPrint('Error getting challenge participants: $e');
      return [];
    }
  }

  // appwrite_service.dart

  // این متد فقط برای نمایش چالش‌های جدید (قابل ثبت‌نام) استفاده می‌شه
  Future<List<Map<String, dynamic>>> getAvailableChallenges() async {
    try {
      final now = DateTime.now().toIso8601String();
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'challenges',
        queries: [
          Query.equal('isActive', true),
          Query.greaterThan('registrationEndDate', now), // فقط ثبت‌نام فعال
        ],
      );
      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting available challenges: $e');
      return [];
    }
  }

  // این متد برای گرفتن یک چالش خاص با استفاده از ID
  Future<Map<String, dynamic>?> getChallengeById(String challengeId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: 'challenges',
        documentId: challengeId,
      );
      final data = doc.data;
      data['id'] = doc.$id;
      return data;
    } catch (e) {
      debugPrint('Error getting challenge by id: $e');
      return null;
    }
  }

  // appwrite_service.dart

  Future<void> cleanupExpiredChallenges(String userId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'user_challenges',
        queries: [Query.equal('userId', userId)],
      );

      final now = DateTime.now();

      for (var doc in result.documents) {
        final challengeId = doc.data['challengeId'];
        if (challengeId == null) continue;

        try {
          final challenge = await databases.getDocument(
            databaseId: databaseId,
            collectionId: 'challenges',
            documentId: challengeId,
          );

          final endDate = DateTime.parse(challenge.data['endDate']);

          // اگه چالش تموم شده، رکورد رو پاک کن
          if (now.isAfter(endDate)) {
            await databases.deleteDocument(
              databaseId: databaseId,
              collectionId: 'user_challenges',
              documentId: doc.$id,
            );
            debugPrint('Removed expired challenge: ${challenge.data['title']}');
          }
        } catch (e) {
          // اگه چالش دیگه وجود نداره، رکورد رو پاک کن
          await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: 'user_challenges',
            documentId: doc.$id,
          );
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up expired challenges: $e');
    }
  }

  // ==================== پیشرفت واقعی چالش ====================

  // دریافت پیشرفت واقعی چالش بر اساس روزهای انجام شده
  Future<double> getUserChallengeRealProgress(
    String userId,
    String challengeTitle,
  ) async {
    try {
      // پیدا کردن عادت چالش
      final habits = await getHabits(userId);
      final challengeHabit = habits.firstWhere(
        (h) => h.title.contains(challengeTitle) || h.title.contains('🏆 چالش:'),
        orElse: () => throw Exception('چالش پیدا نشد'),
      );

      // گرفتن تاریخ شروع و پایان چالش
      final startDate = challengeHabit.startDate;
      final endDate = challengeHabit.endDate;

      if (startDate == null || endDate == null) {
        debugPrint('تاریخ شروع یا پایان چالش مشخص نیست');
        return 0.0;
      }

      // محاسبه کل روزهای چالش
      final totalDays = endDate.difference(startDate).inDays + 1;

      if (totalDays <= 0) return 0.0;

      // شمارش روزهایی که کاربر انجام داده
      int completedDays = 0;
      final now = DateTime.now();

      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));

        // فقط روزهایی که تا امروز گذشته رو بررسی کن
        if (date.isAfter(now)) continue;

        final isCompleted = await isHabitCompletedOnDate(
          challengeHabit.id,
          userId,
          date,
        );

        if (isCompleted) {
          completedDays++;
        }
      }

      debugPrint(
        'پیشرفت چالش $challengeTitle: $completedDays از $totalDays روز انجام شده',
      );
      return completedDays / totalDays;
    } catch (e) {
      debugPrint('Error getting challenge real progress: $e');
      return 0.0;
    }
  }

  /// دریافت جزئیات پیشرفت واقعی چالش بر اساس روزهای انجام شده
  /// returns: Map<String, int> شامل completedDays و totalDays
  Future<Map<String, int>> getUserChallengeProgressDetails(
    String userId,
    String challengeId,
  ) async {
    try {
      debugPrint('📊 شروع محاسبه پیشرفت چالش: $challengeId');

      // 1. دریافت همه عادت‌های کاربر
      final habits = await getHabits(userId);
      debugPrint('📋 تعداد کل عادت‌ها: ${habits.length}');

      // 2. پیدا کردن عادت چالش با challengeId
      Habit? challengeHabit;
      try {
        challengeHabit = habits.firstWhere((h) => h.challengeId == challengeId);
      } catch (e) {
        debugPrint('⚠️ عادت با challengeId $challengeId پیدا نشد!');
        return {'completedDays': 0, 'totalDays': 0};
      }

      if (challengeHabit == null) {
        debugPrint('❌ چالش پیدا نشد');
        return {'completedDays': 0, 'totalDays': 0};
      }

      debugPrint('✅ عادت چالش پیدا شد: ${challengeHabit.title}');
      debugPrint('📅 تاریخ شروع: ${challengeHabit.startDate}');
      debugPrint('📅 تاریخ پایان: ${challengeHabit.endDate}');

      // 3. بررسی تاریخ‌ها
      final startDate = challengeHabit.startDate;
      final endDate = challengeHabit.endDate;

      if (startDate == null || endDate == null) {
        debugPrint('⚠️ تاریخ شروع یا پایان null است');
        return {'completedDays': 0, 'totalDays': 0};
      }

      // 4. محاسبه کل روزهای چالش
      final totalDays = endDate.difference(startDate).inDays + 1;
      debugPrint('📊 کل روزهای چالش: $totalDays');

      // 5. شمارش روزهایی که کاربر انجام داده
      int completedDays = 0;
      final now = DateTime.now();

      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));

        // فقط روزهایی که تا امروز گذشته رو بررسی کن
        if (date.isAfter(now)) {
          debugPrint('⏳ روز ${i + 1}: $date - آینده (رد می‌شود)');
          continue;
        }

        final isCompleted = await isHabitCompletedOnDate(
          challengeHabit.id,
          userId,
          date,
        );

        if (isCompleted) {
          completedDays++;
          debugPrint('✅ روز ${i + 1}: $date - انجام شده');
        } else {
          debugPrint('❌ روز ${i + 1}: $date - انجام نشده');
        }
      }

      debugPrint('🎯 نتیجه نهایی: $completedDays از $totalDays روز انجام شده');

      return {'completedDays': completedDays, 'totalDays': totalDays};
    } catch (e, stackTrace) {
      debugPrint('❌ خطا در getUserChallengeProgressDetails: $e');
      debugPrint('StackTrace: $stackTrace');
      return {'completedDays': 0, 'totalDays': 0};
    }
  }

  // حذف عادت‌های منقضی شده
  Future<void> cleanupExpiredHabits(String userId) async {
    try {
      final habits = await getHabits(userId);
      final now = DateTime.now();

      for (var habit in habits) {
        if (habit.endDate != null && now.isAfter(habit.endDate!)) {
          await deleteHabit(habit.id);
          debugPrint('حذف عادت منقضی: ${habit.title}');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning expired habits: $e');
    }
  }

  // appwrite_service.dart

  /// حذف عادت‌های مربوط به یک چالش از کاربر
  Future<void> removeChallengeTasksFromUser(
    String userId,
    String challengeTitle,
  ) async {
    try {
      debugPrint('🗑️ شروع حذف عادت‌های چالش: $challengeTitle');

      // 1. دریافت همه عادت‌های کاربر
      final habits = await getHabits(userId);
      debugPrint('📋 تعداد کل عادت‌ها: ${habits.length}');

      // 2. پیدا کردن عادت‌های مربوط به چالش
      final challengeHabits = habits.where((habit) {
        // عادت‌هایی که عنوانشون شامل عنوان چالش باشه
        final title = habit.title;
        return title.contains(challengeTitle) ||
            title.contains(challengeTitle.replaceAll('🏆', '').trim()) ||
            title.contains('🏆 چالش: $challengeTitle');
      }).toList();

      if (challengeHabits.isEmpty) {
        debugPrint('⚠️ هیچ عادتی برای چالش $challengeTitle پیدا نشد');
        return;
      }

      debugPrint('✅ ${challengeHabits.length} عادت پیدا شد');

      // 3. حذف هر عادت
      for (var habit in challengeHabits) {
        await deleteHabit(habit.id);
        debugPrint('🗑️ عادت "${habit.title}" حذف شد');
      }

      debugPrint('✅ همه عادت‌های چالش $challengeTitle حذف شدند');
    } catch (e) {
      debugPrint('❌ Error removing challenge tasks: $e');
      rethrow;
    }
  }

  /// حذف عادت چالش با استفاده از challengeId
  Future<void> removeChallengeHabitByChallengeId(
    String userId,
    String challengeId,
  ) async {
    try {
      debugPrint('🗑️ شروع حذف عادت چالش با ID: $challengeId');

      // دریافت همه عادت‌های کاربر
      final habits = await getHabits(userId);

      // پیدا کردن عادت با challengeId
      final challengeHabits = habits.where((habit) {
        return habit.challengeId == challengeId;
      }).toList();

      if (challengeHabits.isEmpty) {
        debugPrint('⚠️ هیچ عادتی با challengeId $challengeId پیدا نشد');
        return;
      }

      // حذف هر عادت
      for (var habit in challengeHabits) {
        await deleteHabit(habit.id);
        debugPrint('🗑️ عادت "${habit.title}" حذف شد');
      }

      debugPrint('✅ همه عادت‌های چالش با ID $challengeId حذف شدند');
    } catch (e) {
      debugPrint('❌ Error removing challenge habit by id: $e');
      rethrow;
    }
  }
}
