// lib/features/explore/screens/quest_completion_screen.dart

import 'package:flutter/material.dart';
import '../models/quest_model.dart';
import '../widgets/completion_view.dart';

class QuestCompletionScreen extends StatelessWidget {
  final Quest quest;
  final int completedDays;

  const QuestCompletionScreen({
    super.key,
    required this.quest,
    required this.completedDays,
  });

  @override
  Widget build(BuildContext context) {
    return CompletionView(
      subtitle: 'شما ماموریت را با موفقیت کامل کردید!',
      name: quest.title,
      progressText: '$completedDays روز از ${quest.targetCount} روز',
      badgeText: quest.badge.isEmpty ? 'ماموریت کامل' : quest.badge,
      xp: quest.xpReward,
    );
  }
}
