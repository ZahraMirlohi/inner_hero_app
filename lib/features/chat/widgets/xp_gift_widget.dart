// lib/features/chat/widgets/xp_gift_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.stars, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                '🎁 هدیه XP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$senderName به $receiverName $amount XP هدیه داد!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textColor,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$message"',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
