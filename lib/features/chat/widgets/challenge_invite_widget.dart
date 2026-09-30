// lib/features/chat/widgets/challenge_invite_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challenge_invite.dart';
import '../utils/chat_colors.dart';
import '/providers/theme_provider.dart';

class ChallengeInviteWidget extends StatefulWidget {
  final ChallengeInvite challenge;
  final bool isMe;
  final Function(bool) onRespond;

  const ChallengeInviteWidget({
    super.key,
    required this.challenge,
    required this.isMe,
    required this.onRespond,
  });

  @override
  State<ChallengeInviteWidget> createState() => _ChallengeInviteWidgetState();
}

class _ChallengeInviteWidgetState extends State<ChallengeInviteWidget> {
  bool _isResponding = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    // ✅ رنگ‌های استاندارد بر اساس تم روز/شب
    final Color bgColor = widget.isMe
        ? ChatColors.myBubble(theme)
        : ChatColors.otherBubble(theme);
    final Color textColor = widget.isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = widget.isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    final isPending = widget.challenge.status == ChallengeStatus.pending;
    final isRejected = widget.challenge.status == ChallengeStatus.rejected;
    final isCancelled = widget.challenge.status == ChallengeStatus.cancelled;

    final bool showRespondButtons = isPending && !widget.isMe && !_isResponding;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor, // ✅ پس‌زمینه پویا
        borderRadius: BorderRadius.circular(18),
        border: isPending
            ? Border.all(
                color: textColor.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: textColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.challenge.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.challenge.duration} روز • ${widget.challenge.xpReward} XP',
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(textColor, bgColor),
            ],
          ),
          const SizedBox(height: 10),

          // ==================== توضیحات ====================
          if (widget.challenge.description.isNotEmpty)
            Text(
              widget.challenge.description,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),

          // ==================== لیست عادت‌ها ====================
          Text(
            '📋 عادت‌های چالش:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.challenge.habits.map((habit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: textColor,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // ==================== دکمه‌های پاسخ ====================
          if (showRespondButtons) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isResponding ? null : () => _respond(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: bgColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isResponding
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: bgColor,
                            ),
                          )
                        : Text(
                            'قبول چالش 🚀',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: bgColor,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResponding ? null : () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'رد کردن',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ==================== وضعیت نهایی ====================
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'این دعوت رد شده است',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'این چالش لغو شده است',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // ==================== فوتر ====================
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${widget.challenge.creatorName} ➜ ${widget.challenge.opponentName}',
                style: TextStyle(
                  fontSize: 9,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Color textColor, Color bgColor) {
    Color color;
    String label;

    switch (widget.challenge.status) {
      case ChallengeStatus.pending:
        color = Colors.orange;
        label = '⏳ در انتظار';
        break;
      case ChallengeStatus.accepted:
        color = textColor;
        label = '✅ پذیرفته شد';
        break;
      case ChallengeStatus.active:
        color = textColor;
        label = '🔥 فعال';
        break;
      case ChallengeStatus.completed:
        color = textColor;
        label = '🏆 کامل شد';
        break;
      case ChallengeStatus.cancelled:
        color = Colors.orange;
        label = '⛔ لغو شد';
        break;
      case ChallengeStatus.rejected:
        color = Colors.red;
        label = '❌ رد شد';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _respond(bool accept) async {
    setState(() {
      _isResponding = true;
    });

    await widget.onRespond(accept);

    if (mounted) {
      setState(() {
        _isResponding = false;
      });
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }
}
