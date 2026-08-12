// lib/features/chat/widgets/challenge_invite_widget.dart

import 'package:flutter/material.dart';
import '../models/challenge_invite.dart';

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
    final isPending = widget.challenge.status == ChallengeStatus.pending;
    final isRejected = widget.challenge.status == ChallengeStatus.rejected;
    final isCancelled = widget.challenge.status == ChallengeStatus.cancelled;

    // اگر کاربر خودش ایجاد کننده است، دکمه‌های پاسخ رو نشون نده
    final bool isCreator =
        widget.challenge.creatorId ==
        widget.challenge.creatorId; // این رو در جای درست چک کنید
    final bool showRespondButtons = isPending && !widget.isMe && !_isResponding;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xFF4A90E2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: isPending ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.orange,
                  size: 20,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isMe
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.challenge.duration} روز • ${widget.challenge.xpReward} XP',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isMe
                            ? Colors.white70
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // وضعیت
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 10),

          // ==================== توضیحات ====================
          if (widget.challenge.description.isNotEmpty)
            Text(
              widget.challenge.description,
              style: TextStyle(
                fontSize: 13,
                color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),

          // ==================== لیست عادت‌ها ====================
          const Text(
            '📋 عادت‌های چالش:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.challenge.habits.map((habit) {
            final iconColor = Color(habit.iconColor);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: iconColor,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isMe
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
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
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isResponding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'قبول چالش 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'رد کردن',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ==================== وضعیت نهایی ====================
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'این دعوت رد شده است',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'این چالش لغو شده است',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ==================== فوتر ====================
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                // ✅ اصلاح: نمایش درست فرستنده و گیرنده
                '${widget.challenge.creatorName} ➜ ${widget.challenge.opponentName}',
                style: TextStyle(
                  fontSize: 9,
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildStatusBadge() {
    Color color;
    String label;

    switch (widget.challenge.status) {
      case ChallengeStatus.pending:
        color = Colors.orange;
        label = '⏳ در انتظار';
        break;
      case ChallengeStatus.accepted:
        color = Colors.blue;
        label = '✅ پذیرفته شد';
        break;
      case ChallengeStatus.active:
        color = Colors.green;
        label = '🔥 فعال';
        break;
      case ChallengeStatus.completed:
        color = Colors.purple;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: widget.isMe ? Colors.white : color,
        ),
      ),
    );
  }

  // lib/features/chat/widgets/challenge_invite_widget.dart

  Future<void> _respond(bool accept) async {
    setState(() {
      _isResponding = true;
    });

    // ✅ صدا زدن onRespond با پارامتر accept
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
