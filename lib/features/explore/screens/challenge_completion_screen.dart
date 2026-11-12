// lib/features/explore/screens/challenge_completion_screen.dart

import '/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../widgets/completion_view.dart';

class ChallengeCompletionScreen extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final int completedDays;
  final int totalDays;

  const ChallengeCompletionScreen({
    super.key,
    required this.challenge,
    required this.completedDays,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return CompletionView(
      subtitle: context.tr('ex.done.sub.challenge'),
      name: challenge['title'] ?? context.tr('ex.challenge'),
      progressText: context.tr('ex.days_of', {'n': '$completedDays', 'm': '$totalDays'}),
      badgeText: context.tr('ex.done.badge.challenge'),
      xp: (challenge['xp_reward'] as int?) ?? 0,
    );
  }
}
