// lib/features/profile/widgets/hero_stats.dart

import 'package:flutter/material.dart';
import '../models/character_model.dart';

class HeroStats extends StatelessWidget {
  final Character character;

  const HeroStats({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آمار قهرمان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.cake,
                  label: 'سن قهرمان',
                  value: '${character.characterAge} روز',
                  color: const Color(0xFF2563EB),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.stars,
                  label: 'لول',
                  value: '${character.level}',
                  color: const Color(0xFFFFA500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_fire_department,
                  label: 'استریک جاری',
                  value: '${character.streak} روز',
                  color: const Color(0xFFE74C3C),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.emoji_events,
                  label: 'مدال‌ها',
                  value: '${character.badges}',
                  color: const Color(0xFFF39C12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildXpBar(),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBar() {
    final progress = character.levelProgress;
    final xpNeeded = character.level * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'پیشرفت به لول بعدی',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '${character.xp} / $xpNeeded XP',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF2563EB),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
