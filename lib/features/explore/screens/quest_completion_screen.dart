// lib/features/explore/screens/quest_completion_screen.dart

import '/l10n/app_strings.dart';
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
      subtitle: context.tr('ex.done.sub.quest'),
      name: quest.title,
      progressText: context.tr('ex.days_of', {'n': '$completedDays', 'm': '${quest.targetCount}'}),
      badgeText: quest.badge.isEmpty ? context.tr('ex.done.badge.quest') : quest.badge,
      xp: quest.xpReward,
    );
  }
}
