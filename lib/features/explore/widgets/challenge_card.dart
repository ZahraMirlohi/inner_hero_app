import 'package:flutter/material.dart';

class ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final bool isRegistrationClosed;
  final VoidCallback onTap;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.isRegistrationClosed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isRegistrationClosed
        ? Colors.grey.shade300
        : _parseColor(challenge['color'] ?? '#FFB8B8');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isRegistrationClosed
              ? []
              : [
                  BoxShadow(
                    color: bgColor.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // محتوای کارت
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isRegistrationClosed
                              ? Colors.grey.shade400
                              : Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRegistrationClosed ? '⛔ پایان ثبت‌نام' : '🔥 داغ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isRegistrationClosed
                                ? Colors.grey.shade600
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // تعداد شرکت‌کنندگان
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isRegistrationClosed
                              ? Colors.grey.shade400
                              : Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              size: 12,
                              color: Color(0xFF1A1A2E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${challenge['participants'] ?? 0} نفر',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    challenge['title'] ?? 'بدون عنوان',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isRegistrationClosed
                          ? Colors.grey.shade600
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    challenge['description'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isRegistrationClosed
                          ? Colors.grey.shade500
                          : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
    }
  }
}
