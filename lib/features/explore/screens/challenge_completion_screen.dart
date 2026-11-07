// lib/features/explore/screens/challenge_completion_screen.dart

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
      subtitle: 'شما چالش را با موفقیت کامل کردید!',
      name: challenge['title'] ?? 'چالش',
      progressText: '$completedDays روز از $totalDays روز',
      badgeText: 'چالش کامل',
      xp: (challenge['xp_reward'] as int?) ?? 0,
    );
  }
}
