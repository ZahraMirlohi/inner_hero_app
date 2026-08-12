// lib/features/chat/widgets/xp_gift_widget.dart

import 'package:flutter/material.dart';

class XPGiftWidget extends StatelessWidget {
  final int amount;
  final String senderName;
  final String receiverName;
  final String message;
  final bool isMe;

  const XPGiftWidget({
    super.key,
    required this.amount,
    required this.senderName,
    required this.receiverName,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFA500).withValues(alpha: 0.1),
            const Color(0xFFFFD700).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFA500).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFA500), size: 24),
              const SizedBox(width: 8),
              Text(
                '🎁 هدیه XP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFA500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$senderName به $receiverName $amount XP هدیه داد!',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"$message"',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
